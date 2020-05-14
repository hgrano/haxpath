{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE UndecidableInstances #-}

module HaXPath.Schematic(
  and,
  Expression,
  IsExpression,
  IsPath(..),
  NodeAttribute,
  NodeAttributes,
  NodesAttributes,
  not,
  or,
  Path,
  RelativePath,
  text,
  Union,
  unsafeAt,
  (=.),
  (/=.),
  (<.),
  (<=.),
  (>.),
  (>=.),
  (/.),
  (#)
) where

import qualified Data.String as S
import qualified Data.Text as T
import qualified HaXPath as X
import Prelude ((.), ($))
import qualified Prelude as P

-- | The union of two sets of types.
class Union (l :: [*]) (m :: [*]) (lm :: [*]) | l m -> lm

instance Union '[] m m

instance Union l' m lm => Union (l ': l') m (l ': lm)

-- | An XPath expression returning a value of type 'x', involving zero or more attributes 'a'.
newtype Expression (x :: *) (a :: [*]) = Expression { unExpression :: X.Expression x }

-- | Type class for expressions. Do not create your own instances of this class.
class IsExpression (h :: *) (x :: *) (a :: [*]) | h -> x a where
  -- | Convert a haskell value to an XPath expression.
  toExpression :: h -> Expression x a

instance IsExpression P.String X.Text '[] where
  toExpression = Expression . S.fromString

instance IsExpression P.Integer X.Number '[] where
  toExpression = Expression . P.fromInteger

instance IsExpression P.Bool X.Bool '[] where
  toExpression = Expression . X.toExpression

instance IsExpression (Expression x a) x a where
  toExpression = P.id

-- | The XPath @text()@ function.
text :: Expression X.Text '[]
text = Expression X.text

-- | The XPath @or()@ function.
or :: (IsExpression h1 X.Bool a, IsExpression h2 X.Bool b, Union a b c) =>
      h1 -> h2 -> Expression X.Bool c
x `or` y = Expression $ unExpression (toExpression x) `X.or` unExpression (toExpression y)
infixr 4 `or`

-- | The XPath @and@ operator.
and :: (IsExpression h1 X.Bool a, IsExpression h2 X.Bool b, Union a b c) =>
      h1 -> h2 -> Expression X.Bool c
x `and` y = Expression $ unExpression (toExpression x) `X.and` unExpression (toExpression y)
infixr 5 `and`

-- | The XPath @not()@ function.
not :: IsExpression h X.Bool a => h -> Expression X.Bool a
not = Expression . X.not . unExpression . toExpression

-- | Access the value of a node's attribute in text form (equivalent to XPath's @\@@). Unsafe because it has no way to
-- check if the attribute name provided matches the schema. It is recommend to call this function once only for each
-- attribute in your schema. The resulting value can be re-used.
unsafeAt :: T.Text -> Expression X.Text a
unsafeAt = Expression . X.at

binary :: (IsExpression h1 x1 a1, IsExpression h2 x2 a2, Union a1 a2 a3) =>
          (X.Expression x1 -> X.Expression x2 -> X.Expression x3) -> h1 -> h2 -> Expression x3 a3
binary op x y = Expression $ unExpression (toExpression x) `op` unExpression (toExpression y)

-- | The XPath @=@ operator.
(=.) :: (X.Eq x, IsExpression h1 x a, IsExpression h2 x b, Union a b c) =>
        h1 -> h2 -> Expression X.Bool c
(=.) = binary (X.=.)

-- | The XPath @!=@ operator.
(/=.) :: (X.Eq x, IsExpression h1 x a, IsExpression h2 x b, Union a b c) =>
        h1 -> h2 -> Expression X.Bool c
(/=.) = binary (X./=.)

-- | The XPath @<@ operator.
(<.) :: (X.Ord x, IsExpression h1 x a, IsExpression h2 x b, Union a b c) =>
        h1 -> h2 -> Expression X.Bool c
(<.) = binary (X.<.)

-- | The XPath @<=@ operator.
(<=.) :: (X.Ord x, IsExpression h1 x a, IsExpression h2 x b, Union a b c) =>
        h1 -> h2 -> Expression X.Bool c
(<=.) = binary (X.<=.)

-- | The XPath @>@ operator.
(>.) :: (X.Ord x, IsExpression h1 x a, IsExpression h2 x b, Union a b c) =>
        h1 -> h2 -> Expression X.Bool c
(>.) = binary (X.>.)

-- | The XPath @>=@ operator.
(>=.) :: (X.Ord x, IsExpression h1 x a, IsExpression h2 x b, Union a b c) =>
        h1 -> h2 -> Expression X.Bool c
(>=.) = binary (X.>=.)

-- | A relative XPath for a schema 's' returning a set of nodes which may any of the type-list 'n'. This type doesn't
-- have a precise XPath native equivalent, but it is useful to ensure when combining paths (e.g. through '/.') that the 
-- resulting XPath is valid. It is analagous to the use of relative paths in a unix-based operating system.
newtype RelativePath (s :: *) (n :: [*]) = RelativePath  { unRelativePath :: X.RelativePath }

-- | The type of XPaths for a schema 's' returning a set of nodes which may any of the type-list 'n'.
newtype Path (s :: *) (n :: [*]) = Path { unPath :: X.Path }

instance IsExpression (Path s n) X.NodeSet '[] where
  toExpression = Expression . unPath

-- | Type class for allowing XPath-like operations. Do not create instances of this class.
class X.IsPath u => IsPath (t :: * -> [*] -> *) (u :: *) | t -> u where
  -- | Convert a schematic XPath to its non-schematic equivalent.
  toNonSchematicPath :: t s n -> u

  -- | Unsafely convert a non-schematic XPath to its schematic equivalent without type checking.
  unsafeFromNonSchematicPath :: u -> t s n

instance IsPath RelativePath X.RelativePath where
  toNonSchematicPath = unRelativePath

  unsafeFromNonSchematicPath = RelativePath

instance IsPath Path X.Path where
  toNonSchematicPath = unPath

  unsafeFromNonSchematicPath = Path

-- | Witnesses that a node of type 'n' may have an attribute of type 'a'.
class NodeAttribute n a

-- | Witnesses that a node of type 'n' may have zero or more of a set of attributes 'a'.
class NodeAttributes (n :: *) (a :: [*])

instance (NodeAttribute n h, NodeAttributes n t) => NodeAttributes n (h ': t)

instance NodeAttributes n '[]

-- | Witnesses that a set of nodes 'n' may have zero or more of a set of attributes 'a'.
class NodesAttributes (n :: [*]) (a :: [*])

instance (NodeAttributes n a, NodesAttributes n' a) => NodesAttributes (n ': n') a

instance NodesAttributes '[] a

(/.) :: IsPath p u => p s m -> RelativePath s n -> p s n
p1 /. p2 = unsafeFromNonSchematicPath $ toNonSchematicPath p1 X./. toNonSchematicPath p2
infixr 2 /.

(#) :: (IsPath p u, NodesAttributes n a) => p s n -> Expression X.Bool a -> p s n
p # expr = unsafeFromNonSchematicPath $ toNonSchematicPath p X.# unExpression expr
