{-# LANGUAGE OverloadedStrings #-}

module HaXPath.Test (suite) where

import qualified Test.HUnit as H
import HaXPath ((/.), (./.), (//.), (=.), (/=.), (<.), (<=.), (>.), (>=.), (#))
import qualified HaXPath as X

a :: X.Node
a = X.namedNode "a"

b :: X.Node
b = X.namedNode "b"

c :: X.Node
c = X.namedNode "c"

testAppend :: H.Test
testAppend = H.TestLabel "append" . H.TestCase $ do
  H.assertEqual
    "Child"
    "/descendant-or-self::node()/child::a/child::b" 
    (X.show . X.fromRoot $ X.descendantOrSelf X.node ./. X.child a ./. X.child b)
  H.assertEqual
    "Child(abbrev)"
    "/descendant-or-self::node()/child::a/child::b" 
    (X.show $ X.doubleSlash a /. b)
  H.assertEqual
    "Descendent or self"
    "/descendant-or-self::node()/child::a/descendant-or-self::node()/child::b"
    (X.show $ X.doubleSlash a //. b)

testAttribute :: H.Test
testAttribute = H.TestLabel "attribute" . H.TestCase $
  H.assertEqual "Attribute equality" "(child::a)[@id = 'hello']" (X.showRelativePath $ X.child a # X.at "id" =. "hello")

testBool :: H.Test
testBool = H.TestLabel "bool" . H.TestCase $ do
  H.assertEqual
    "and"
    "(child::a)[(text() = 'abc') and contains(@id, 'def')]"
    (X.showRelativePath $ X.child a # X.text =. "abc" `X.and` X.contains (X.at "id") "def")
  H.assertEqual
    "or"
    "(child::a)[(text() = 'abc') or contains(@id, 'def')]"
    (X.showRelativePath $ X.child a # X.text =. "abc" `X.or` X.contains (X.at "id") "def")
  H.assertEqual
    "not"
    "(child::a)[(text() = 'abc') or contains(@id, 'def')]"
    (X.showRelativePath $ X.child a # X.text =. "abc" `X.or` X.contains (X.at "id") "def")
  H.assertEqual
    "!="
    "(child::a)[text() != 'abc']"
    (X.showRelativePath $ X.child a # X.text /=. "abc")
  H.assertEqual
    "true"
    "(child::a)[true()]"
    (X.showRelativePath $ X.child a # True)
  H.assertEqual
    "false"
    "(child::a)[false()]"
    (X.showRelativePath $ X.child a # False)

testContext :: H.Test
testContext = H.TestLabel "context" . H.TestCase $ do
  H.assertEqual "//" "/descendant-or-self::node()/child::a" (X.showPath $ X.doubleSlash a)
  H.assertEqual "/" "/child::a" (X.showPath . X.fromRoot $ X.child a)

testFunction :: H.Test
testFunction = H.TestLabel "function" . H.TestCase $ do
  H.assertEqual "text()" "(child::a)[text() = 'hello']" (X.showRelativePath $ X.child a # X.text =. "hello")
  H.assertEqual
    "contans()"
    "(child::a)[contains(text(), 'hello')]"
    (X.showRelativePath $ X.child a # X.text `X.contains` "hello")

testNum :: H.Test
testNum = H.TestLabel "num" . H.TestCase $ do
  H.assertEqual "+" "(child::a)[(position() + 1) = 2]" (X.showRelativePath $ X.child a # X.position + 1 =. 2)
  H.assertEqual "+" "(child::a)[(position() - 1) = 2]" (X.showRelativePath $ X.child a # X.position - 1 =. 2)
  H.assertEqual "*" "(child::a)[(position() * 2) = 4]" (X.showRelativePath $ X.child a # X.position * 2 =. 4)
  H.assertEqual
    "signum"
    "(child::a)[position() = (((0 - 4) > 0) - ((0 - 4) < 0))]"
    (X.showRelativePath $ X.child a # X.position =. signum (-4))
  H.assertEqual
    "abs" "(child::a)[position() = ((0 - 4) * (((0 - 4) > 0) - ((0 - 4) < 0)))]"
    (X.showRelativePath $ X.child a # X.position =. abs (-4))

testOrd :: H.Test
testOrd = H.TestLabel "ord" . H.TestCase $ do
  H.assertEqual "<" "(child::a)[2 < position()]" (X.showRelativePath $ X.child a # 2 <. X.position)
  H.assertEqual "<" "(child::a)[2 <= position()]" (X.showRelativePath $ X.child a # 2 <=. X.position)
  H.assertEqual ">" "(child::a)[2 > position()]" (X.showRelativePath $ X.child a # 2 >. X.position)
  H.assertEqual ">=" "(child::a)[2 >= position()]" (X.showRelativePath $ X.child a # 2 >=. X.position)

testPath :: H.Test
testPath = H.TestLabel "path" . H.TestCase $ do
  H.assertEqual
    "filter node"
    "/descendant-or-self::node()/child::a/child::b/child::c[@id = 'id']"
    (X.show $ X.doubleSlash a /. b /. (c # X.at "id" =. "id"))

  H.assertEqual
    "filter absolute"
    "(/descendant-or-self::node()/child::a/child::b/child::c)[@id = 'id']"
    (X.show $ (X.doubleSlash a /. b /. c) # X.at "id" =. "id")

--  H.assertEqual
--    "bracket"
--    "(/descendant-or-self::node()/child::a/child::b/child::c)[@id = 'id']"
--    (X.showIsPath $ (X.fromAnywhere "a" /. "b" /. "c") # X.at "id" =. "id")

suite :: H.Test
suite = H.TestLabel "HaXPath" $ H.TestList [
    testAppend,
    testAttribute,
    testBool,
    testContext,
    testFunction,
    testNum,
    testOrd,
    testPath
  ]
