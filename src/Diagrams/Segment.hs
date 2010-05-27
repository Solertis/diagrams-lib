{-# LANGUAGE TypeFamilies, FlexibleContexts, DeriveFunctor #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Diagrams.Segment
-- Copyright   :  (c) Brent Yorgey 2010
-- License     :  BSD-style (see LICENSE)
-- Maintainer  :  byorgey@cis.upenn.edu
-- Stability   :  experimental
-- Portability :  portable
--
-- Generic functionality for constructing and manipulating linear or
-- cubic Bezier segments.
--
-----------------------------------------------------------------------------

module Diagrams.Segment
       ( -- * Construction

         Segment(..), straight, bezier3

         -- * Computation
       , atParam, segOffset

       , segmentBounds
       ) where

import Graphics.Rendering.Diagrams

import Data.VectorSpace

------------------------------------------------------------
--  Constructing segments  ---------------------------------
------------------------------------------------------------

-- | The atomic constituents of paths are /segments/, which are single
--   straight lines or cubic Bezier curves.  Segments are
--   /translationally invariant/, that is, they have translational
--   freedom.  For example, a linear segment has a definite length and
--   direction, but no definite location in space.
data Segment v = Linear v
               | Cubic v v v
  deriving (Show, Functor)

-- | Note that since segments are translationally invariant,
--   translating a segment has no effect.  Thus the translational
--   component of a transformation is always ignored, but other
--   components (scaling, rotation, ...) will have an effect.
instance (Transformable v, AdditiveGroup v) => Transformable (Segment v) where
  type TSpace (Segment v) = TSpace v
  transform t = fmap (\v -> transform t v ^-^ z)
    where z = transform t zeroV

-- | @'straight' v@ constructs a translationally invariant linear
--   segment with direction and length given by the vector @v@.
straight :: (VectorSpace v, Fractional (Scalar v)) => v -> Segment v
straight v = Linear v

-- Note, if we didn't have a Linear constructor we could also create
-- linear segments with @Cubic (v ^/ 3) (2 *^ (v ^/ 3)) v@.

-- | @'bezier3' v1 v2 v3@ constructs a translationally invariant cubic
--   Bezier curve where the offsets from the first endpoint to the
--   first and second control point and endpoint are respectively
--   given by @v1@, @v2@, and @v3@.
bezier3 :: v -> v -> v -> Segment v
bezier3 = Cubic

-- | 'atParam' yields a parametrized view of segments as continuous
--   functions @[0,1] -> V@, which give the offset from the start of
--   the segment for each value of the parameter @0@ and @1@.  It is
--   designed to be used infix, like @seg `atParam` 0.5@.
atParam :: (VectorSpace v, Num (Scalar v)) => Segment v -> Scalar v -> v
atParam (Linear x) t       = t *^ x
atParam (Cubic c1 c2 x2) t =     (3 * (1-t)^2 * t) *^ c1
                             ^+^ (3 * (1-t) * t^2) *^ c2
                             ^+^ t^3 *^ x2

-- | Compute the total offset (a vector) from the start of a segment
--   to the end.
segOffset :: Segment v -> v
segOffset (Linear v)    = v
segOffset (Cubic _ _ v) = v

-- XXX todo: add a function to compute the length of a segment?
--   probably need some heavy-duty numeric methods...

------------------------------------------------------------
--  Computing segment bounds  ------------------------------
------------------------------------------------------------

{- (1-t)^2 t c1 + (1-t) t^2 c2 + t^3 x2

   Can we compute the projection of B(t) onto a given vector v?

   u.v = |u||v| cos th

   |proj_v u| = cos th * |u|
              = (u.v/|v|)

   so B_v(t) = (B(t).v/|v|)

   Then take the derivative of this wrt. t, get a quadratic, solve.

   B_v(t) = (1/|v|) *     -- note this does not affect max/min, can solve for t first
            (1-t)^2 t (c1.v) + (1-t) t^2 (c2.v) + t^3 (x2.v)
          = t^3 ((c1 - c2 + x2).v) + t^2 ((-2c1 + c2).v) + t (c1.v)

   B_v'(t) = t^2 (3(c1 - c2 + x2).v) + t (2(-2c1 + c2).v) + c1.v

   Set equal to zero, use quadratic formula.
-}

quadForm :: (Floating d, Ord d) => d -> d -> d -> [d]
quadForm a b c
  | d < 0     = []
  | d == 0    = [-b/(2*a)]
  | otherwise = [(-b + sqrt d)/(2*a), (-b - sqrt d)/(2*a)]
 where d = b*b - 4*a*c

segmentBounds :: (InnerSpace v, Ord (Scalar v), Floating (Scalar v))
              => Segment v -> Bounds v
segmentBounds s@(Linear x1) = Bounds $ \v ->
  maximum . map (\t -> (s `atParam` t <.> v) / magnitude v) $ [0,1]
segmentBounds s@(Cubic c1 c2 x2) = Bounds $ \v ->
  maximum .
  map (\t -> (s `atParam` t <.> v) / magnitude v) $
  [0,1] ++
  quadForm (3 * ((c1 ^-^ c2 ^+^ x2) <.> v))
           (2 * (((-2) *^ c1 ^+^ c2) <.> v))
           (c1 <.> v)