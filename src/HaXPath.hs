{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module HaXPath(
  and,
  at,
  Bool,
  child,
  contains,
  count,
  descendantOrSelf,
  doubleSlash,
  Expression,
  Eq,
  fromRoot,
  IsExpression(..),
  IsPath(..),
  namedNode,
  node,
  Node,
  NodeSet,
  not,
  Number,
  or,
  Ord,
  Path,
  position,
  RelativePath,
  show,
  text,
  Text,
  (=.),
  (/=.),
  (<.),
  (<=.),
  (>.),
  (>=.),
  (/.),
  (//.),
  (#)
) where

import qualified Data.String as S
import qualified Data.Text as T
import Prelude ((&&), (+), (-), (*), (.), ($), (<>), (<$>))
import qualified Prelude as P

-- | XPath textual (string) data type.
data Text

-- | XPath numeric data type.
data Number

-- | XPath boolean data type.
data Bool

-- | XPath type representing an unordered set of nodes.
data NodeSet

data Expression' = Function T.Text [Expression'] |
                   Operator T.Text Expression' Expression' |
                   Attribute T.Text |
                   TextLiteral T.Text |
                   IntegerLiteral P.Integer |
                   Path PathType RelativePath [Expression']

showExpression :: Expression' -> T.Text
showExpression (Function f es) = f <> "(" <> args <> ")"
  where
    args = T.intercalate ", " $ showExpression <$> es
showExpression (Operator o a b) = showWithBracket a <> " " <> o <> " " <> showWithBracket b
  where
    needsBracket (Operator _ _ _) = P.True
    needsBracket (Path _ _ _) = P.True
    needsBracket _ = P.False

    showWithBracket e = if needsBracket e then "(" <> showExpression e <> ")" else showExpression e

showExpression (Attribute a) = "@" <> a
showExpression (TextLiteral t) = "'" <> t <> "'"
showExpression (IntegerLiteral i) = T.pack $ P.show i
showExpression (Path t p es) =
  let prefix = case t of
        Relative -> ""
        Absolute -> "/"
  in
  let s = prefix <> showRelativePath p in
  if P.not (P.null es) then
    "(" <> s <> ")" <> showExpressions es
  else
    s

showExpressionBracketed :: Expression' -> T.Text
showExpressionBracketed e = "[" <> showExpression e <> "]"

showExpressions :: [Expression'] -> T.Text
showExpressions = T.concat . P.fmap showExpressionBracketed . P.reverse

-- | Opaque representation of an XPath expression.
newtype Expression t = Expression { unExpression :: Expression' }

instance S.IsString (Expression Text) where
  fromString = Expression . TextLiteral . T.pack

-- | The type of XPaths.
type Path = Expression NodeSet

class IsExpression a t | a -> t where
  toExpression :: a -> Expression  t

unIsExpression :: IsExpression a t => a -> Expression'
unIsExpression = unExpression . toExpression

instance IsExpression P.Bool Bool where
  toExpression x = Expression $ Function (if x then "true" else "false") []

instance IsExpression (Expression t) t where
  toExpression = P.id

unsafeCast :: Expression t -> Expression u
unsafeCast (Expression e) = Expression e

boolToInt :: Expression Bool -> Expression Number
boolToInt = unsafeCast

-- | Access the value of a node's attribute in text form (equivalent to XPath's @\@@).
at :: T.Text -> Expression Text
at = Expression . Attribute

-- | Type class of XPath types that can be compared for equality.
class Eq t

instance Eq Text
instance Eq Number
instance Eq Bool

-- | The XPath @=@ operator.
(=.) :: (Eq t, IsExpression a t) => a -> a -> Expression Bool
x =. y = Expression $ Operator "=" (unIsExpression x) (unIsExpression y)
infixr 4 =.

-- | The XPath @!=@ operator.
(/=.) :: (Eq t, IsExpression a t) => a -> a -> Expression Bool
x /=. y = Expression $ Operator "!="(unIsExpression x) (unIsExpression y)
infixr 4 /=.

-- | Type class of XPath types that can be ordered.
class Eq t => Ord t

instance Ord Text
instance Ord Number
instance Ord Bool

-- | The XPath @<@ operator.
(<.) :: (Ord t, IsExpression a t) => a -> a -> Expression Bool
x <. y = Expression $ Operator "<" (unIsExpression x) (unIsExpression y)

-- | The XPath @<=@ operator.
(<=.) :: (Ord t, IsExpression a t) => a -> a -> Expression Bool
x <=. y = Expression $ Operator "<=" (unIsExpression x) (unIsExpression y)

-- | The XPath @>@ operator.
(>.) :: (Ord t, IsExpression a t) => a -> a -> Expression Bool
x >. y = Expression $ Operator ">" (unIsExpression x) (unIsExpression y)

-- | The XPath @>=@ operator.
(>=.) :: (Ord t, IsExpression a t) => a -> a -> Expression Bool
x >=. y = Expression $ Operator ">=" (unIsExpression x) (unIsExpression y)

instance P.Num (Expression Number) where
  Expression x + Expression y = Expression $ Operator "+" x y

  Expression x - Expression y = Expression $ Operator "-" x y

  Expression x * Expression y = Expression $ Operator "*" x y

  abs x = x * P.signum x

  signum x = boolToInt (x >. 0) - boolToInt (x <. 0)

  fromInteger = Expression . IntegerLiteral

-- | The XPath @position()@ function.
position :: Expression Number
position = Expression $ Function "position" []

-- | The XPath @text()@ function.
text :: Expression Text
text = Expression $ Function "text" []

-- | The XPath @contains()@ function.
contains :: IsExpression a Text => a -> a -> Expression Bool
contains x y = Expression . Function "contains" $ [unIsExpression x, unIsExpression y]

-- | The XPath @count()@ function.
count :: IsExpression a NodeSet => a -> Expression Number
count p = Expression $ Function "count" [unIsExpression p]

-- | The XPath @and@ operator.
and :: (IsExpression a Bool, IsExpression b Bool) => a -> b -> Expression Bool
x `and` y = Expression $ Operator "and" (unIsExpression x) (unIsExpression y)
infixr 3 `and`

-- | The XPath @or@ operator.
or :: (IsExpression a Bool, IsExpression b Bool) => a -> b -> Expression Bool
x `or` y = Expression $ Operator "or" (unIsExpression x) (unIsExpression y)
infixr 2 `or`

-- | The XPath @not(.)@ function.
not :: IsExpression a Bool => a -> Expression Bool
not x = Expression $ Function "not" [unIsExpression x]

data Axis = Ancestor |
            Child |
            Descendant |
            DescendantOrSelf |
            Parent

showAxis :: Axis -> T.Text
showAxis axis = case axis of
  Ancestor -> "ancestor"
  Child -> "child"
  Descendant -> "descendant"
  DescendantOrSelf -> "descendant-or-self"
  Parent -> "parent"

data Node = Node {
  nName :: !T.Text,
  nPredicate :: ![Expression']
}

-- | The XPath @node()@ function.
node :: Node
node = Node "node()" []

namedNode :: T.Text -> Node
namedNode n = Node n []

nodeToRelativePath :: Axis -> Node -> RelativePath
nodeToRelativePath axis n = RelativePath {
  rpAxis = axis,
  rpNode = n { nPredicate = [] },
  rpNext = P.Nothing,
  rpPredicate = nPredicate n
}

child :: Node -> RelativePath
child = nodeToRelativePath Child

descendantOrSelf :: Node -> RelativePath
descendantOrSelf = nodeToRelativePath DescendantOrSelf

-- | The XPath @//@ operator.
doubleSlash :: Node -> Path
doubleSlash n = fromRoot $ descendantOrSelf node /. n
-- | A relative XPath, i.e. an XPath that is relative to the current node.
data RelativePath = RelativePath {
  rpAxis :: !Axis,
  rpNode :: !Node,
  rpNext :: !(P.Maybe RelativePath),
  rpPredicate :: ![Expression']
}

instance IsExpression RelativePath NodeSet where
  toExpression p = Expression $ Path Relative p []

showRelativePath :: RelativePath -> T.Text
showRelativePath rp =
  let pred = rpPredicate rp in
  let esStr = showExpressions pred
      nextStr = case rpNext rp of
        P.Just next -> "/" <> showRelativePath next
        P.Nothing -> ""
  in
  let unqual = showAxis (rpAxis rp) <> "::" <> nName (rpNode rp) in -- <> nextStr in
  let qual
        | P.not (P.null pred) && P.not (T.null nextStr) = "(" <> unqual <> ")" <> esStr
        | P.otherwise = unqual <> esStr
  in
  qual <> nextStr

data PathType = Relative | Absolute

-- | Type class for allowing XPath-like operations. Do not create instances of this class.
class IsExpression t NodeSet => IsPath t where
  (./.) :: t -> RelativePath -> t
  infixl 2 ./.

instance IsPath RelativePath where
  rp ./. rp' = case rpNext rp of
    P.Just p -> rp { rpNext = P.Just $ p ./. rp' }
    P.Nothing -> rp { rpNext = P.Just rp' }

class Filterable t where
  (#) :: IsExpression b Bool => t -> b -> t
  infixr 2 #

instance Filterable Node where
  n # e = n { nPredicate = unIsExpression e : nPredicate n }

instance Filterable RelativePath where
  rp # e = rp { rpPredicate = unIsExpression e : rpPredicate rp }

-- | The XPath abbreviated @/@ operator.
(/.) :: IsPath p => p -> Node -> p
p /. n = p ./. child n
infixl 2 /.

-- | The XPath @//@ operator.
(//.) :: IsPath p => p -> Node -> p
p //. n = p ./. descendantOrSelf node ./. child n
infixl 2 //.

-- | Display an XPath expression. This is useful to sending the XPath expression to a separate XPath evaluator e.g.
-- a web browser.
show :: IsPath p => p -> T.Text
show = showExpression . unIsExpression

nonPathError :: a
nonPathError = P.error "HaXPath internal error: unexpected non-Path expression"

instance IsPath Path where
  Expression (Path t rp es) ./. rp' = Expression $ Path t (rp ./. rp') es
  _ ./. _ = nonPathError

instance Filterable Path where
  Expression (Path context rp es) # e = Expression . Path context rp $ unIsExpression e : es
  _ # _ = nonPathError

-- | Fix a relative path to begin from the document root (i.e. create an absolute path).
fromRoot :: RelativePath -> Path
fromRoot rp = Expression $ Path Absolute rp []
