{-# LANGUAGE OverloadedStrings #-}

module HaXPath.Examples where

import           Data.Text         (Text)
import qualified HaXPath           as X
import           HaXPath.Operators

-- Create XPath nodes for elements <a>, <b>, <c>, <d>
a :: X.Node
a = X.namedNode "a"

b :: X.Node
b = X.namedNode "b"

c :: X.Node
c = X.namedNode "c"

d :: X.Node
d = X.namedNode "d"

-- The XPath "child::a/child::b"
p0 :: X.RelativePath
p0 = X.child a /. X.child b

-- The axes can be inferred using abbreviated syntax
p0Abbrev :: X.RelativePath
p0Abbrev = a /. b 

-- The XPath "/descendant-or-self::node()/child::a/child::b"
-- root is a virtual node, and can be used only at the beginning of a path to indicate it is an absolute path
p1 :: X.AbsolutePath
p1 = X.root /. X.descendantOrSelf X.node /. X.child a /. X.child b

-- The same XPath as above but in abbreviated form
p1Abbrev :: X.AbsolutePath
p1Abbrev = X.root //. a /. b

-- Convert paths to `Text`:
p1Raw :: Text
p1Raw = X.show p1 -- "/descendant-or-self::node()/child::a/child::b"

p1AbbrevRaw :: Text
p1AbbrevRaw = X.show p2 -- "/descendant-or-self::node()/child::a/child::b"

-- Qualifiers can be added to filter node sets using the `#` operator:

-- Equivalent of "(/descendant-or-self::node()/child::a/child::b)[position() = 1]"
p1First :: X.AbsolutePath
p1First = p1 # [X.position =. 1]

-- Equivalent of "/descendant-or-self::node()/child::a/child::b[position() = 1]"
p1FirstB :: X.AbsolutePath
p1FirstB = X.root //. a /. b # [X.position =. 1]

-- Equivalent of "/descendant-or-self::node()/child::a[@id = 'abc']/b"
p1FilterById :: X.AbsolutePath
p1FilterById = X.root //. a # [X.at "id" =. "abc"] /. b

-- Note that the second argument to '#' must represent an XPath boolean value, otherwise it will not type check.

-- XPaths can be re-used and composed together in a type-safe manner as shown
p2 :: X.RelativePath
p2 = c /. d

p3 :: X.RelativePath
p3 = c /. d /. d

-- Equivalent of "//a/b/(c/d | c/d/d)"
p4 :: X.AbsolutePath
p4 = p1 /. (p2 |. p3)
