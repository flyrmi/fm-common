#!/bin/sh
exec scala "$0" "$@"
!#

import java.nio.file.Files
import scala.io.Source
import scala.util.matching.Regex

object Line {
  def parse(s: String): Option[Line] = UnicodeChar.parse(s) orElse ASCIIChar.parse(s)
}

sealed trait Line

object UnicodeChar {
  private val pattern: Regex = """          case '(\\u.+)': // (.+)""".r
  def parse(s: String): Option[UnicodeChar] = s match {
    case pattern(char, comment) => Some(UnicodeChar(char, comment))
    case _  => None
  }
}

final case class UnicodeChar(char: String, comment: String) extends Line

object ASCIIChar {
  private val pattern: Regex = """            output\[outputPos\+\+\] = '(.)';""".r
  def parse(s: String): Option[ASCIIChar] = s match {
    case pattern(char) => Some(ASCIIChar(char.charAt(0)))
    case _ => None
  }
}

final case class ASCIIChar(char: Char) extends Line

def getMapping(file: String): Vector[(UnicodeChar, String)] = {
  val lines: Vector[Line] = Source.fromFile(file).getLines.flatMap{ Line.parse }.toVector

  val builder = Vector.newBuilder[(UnicodeChar, String)]

  var unicodeChars = Vector.newBuilder[UnicodeChar]
  var asciiChars = new StringBuilder()

  def reset(): Unit = {
    val ascii: String = asciiChars.result
    unicodeChars.result.foreach{ unicode: UnicodeChar =>
      builder += ((unicode, ascii))
    }
    unicodeChars = Vector.newBuilder[UnicodeChar]
    asciiChars = new StringBuilder()
  }

  lines.foreach{
    case unicode: UnicodeChar => 
      if (asciiChars.nonEmpty) reset()
      unicodeChars += unicode
    case ASCIIChar(char) => asciiChars += char
  }

  builder.result
}

val res: Vector[(UnicodeChar, String)] = getMapping("lucene-solr/lucene/analysis/common/src/java/org/apache/lucene/analysis/miscellaneous/ASCIIFoldingFilter.java")
val groupedByAscii: Vector[(String,Vector[UnicodeChar])] = res.groupBy{ _._2 }.mapValues{ _.map{ _._1 } }.toVector.sortBy{ _._1 }

println(s"""// Generated ${new java.util.Date()}
// AUTO-GENERATED FROM THE makeAccents.sh SCRIPT
// AUTO-GENERATED FROM THE makeAccents.sh SCRIPT
// AUTO-GENERATED FROM THE makeAccents.sh SCRIPT
// AUTO-GENERATED FROM THE makeAccents.sh SCRIPT

/*
 * Copyright 2016 Frugal Mechanic (http://frugalmechanic.com)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package fm.common

import scala.annotation.switch

object ASCIIUtil {
  
  /**
   * Converts Accented Characters to the Non-Accented Equivalent Char.
   * 
   * Note: This only works for when there is a 1 to 1 Character equivalence (i.e. it does not work for stuff like Æ which needs to expand to AE)
   */
  def toASCIIChar(c: Char): Char = {
    // This is potentially more JIT friendly since the JVM should be able
    // to inline this method and will almost always hit the common case
    // of just returning the original character.  The slower path will be
    // calling stripAccentCharImpl()
    if (c < '\\u0080') c else stripAccentCharImpl(c)
  }
  
  /**
   * Converts Accented Characters to the Non-Accented Equivalent String.
   * 
   * Note: This expands stuff like Æ to AE)
   */
  def convertToASCII(s: String): String = {
    s.flatMap{ toASCIIString }
  }
  
  /**
   * Converts Accented Characters to the Non-Accented Equivalent String.
   */
  private def toASCIIString(c: Char): String = {
    // This is potentially more JIT friendly since the JVM should be able
    // to inline this method and will almost always hit the common case
    // of just returning the original character.  The slower path will be
    // calling stripAccentStringImpl()
    if (c < '\\u0080') c.toString else stripAccentStringImpl(c)
  }
  
  ${toASCIICharImpl}
  
  ${toASCIIStringImpl}
}

""")

def toASCIICharImpl: String = {
  val sb = new StringBuilder()
  def println(s: String = ""): Unit = sb.append(s+"\n")

  println("  /** Generated From Lucene's ASCIIFoldingFilter.java */")
  println("  private def stripAccentCharImpl(c: Char): Char = {")
  println("    // Quick test: if it's not in range then just keep current character")
  println("    if (c < '\\u0080') {")
  println("      c")
  println("    } else {")
  println("      (c: @switch) match {")

  groupedByAscii.filter{ case (ascii, _) => ascii.length == 1 }.foreach{ case (ascii, unicodeChars) => 
    println()
    println(s"        // ASCII: $ascii")
    println()
    unicodeChars.foreach{ unicode: UnicodeChar => println (s"        // ${unicode.comment}") }
    println(s"""        case ${unicodeChars.map{ _.char }.mkString("'","' | '","'")} => '${escapeChar(ascii)}'""")
  }

  println()
  println("        case _ => c // Default")
  println("      }")
  println("    }")
  println("  }")

  sb.result
}


def toASCIIStringImpl: String = {
  val sb = new StringBuilder()
  def println(s: String = ""): Unit = sb.append(s+"\n")
  
  println()
  println()
  println("  /** Generated From Lucene's ASCIIFoldingFilter.java */")
  println("  private def stripAccentStringImpl(c: Char): String = {")
  println("    // Quick test: if it's not in range then just keep current character")
  println("    if (c < '\\u0080') {")
  println("      c.toString")
  println("    } else {")
  println("      (c: @switch) match {")

  groupedByAscii.filter{ case (ascii, _) => ascii.length == 1 }.foreach{ case (ascii, unicodeChars) => 
    println()
    println(s"        // ASCII: $ascii")
    println()
    unicodeChars.foreach{ unicode: UnicodeChar => println (s"        // ${unicode.comment}") }
    println(s"""        case ${unicodeChars.map{ _.char }.mkString("'","' | '","'")} => "${escapeString(ascii)}"""")
  }

  println()
  println("        case _ => c.toString // Default")
  println("      }")
  println("    }")
  println("  }")

  sb.result
}

def escapeString(s: String): String = {
  s.flatMap{ 
    case '"' => "\\\""
    case ch => ch.toString
  }
}

def escapeChar(s: String): String = {
  require(s.length == 1)
  val ch: Char = s.charAt(0)
  
  if (ch == '\'') "\'"
  else ch.toString
}