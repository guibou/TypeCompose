{-# LANGUAGE Rank2Types, FlexibleInstances, MultiParamTypeClasses
           , FlexibleContexts, UndecidableInstances, TypeSynonymInstances
           , TypeOperators, GeneralizedNewtypeDeriving, StandaloneDeriving
  #-}
-- For ghc 6.6 compatibility
-- {-# OPTIONS -fglasgow-exts -fallow-undecidable-instances #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

----------------------------------------------------------------------
-- |
-- Module      :  Control.Compose
-- Copyright   :  (c) Conal Elliott 2007
-- License     :  LGPL
-- 
-- Maintainer  :  conal@conal.net
-- Stability   :  experimental
-- Portability :  see LANGUAGE pragma
-- 
-- Various type constructor compositions and instances for them.
-- Some come from 
-- [1] \"Applicative Programming with Effects\"
-- <http://www.soi.city.ac.uk/~ross/papers/Applicative.html>
----------------------------------------------------------------------

module Control.Compose
  ( Unop, Binop
  -- * Contravariant functors
  , Cofunctor(..), bicomap
  -- * Unary\/unary composition
  , (:.)(..), O, biO, convO, coconvO, inO, inO2, inO3
  , fmapFF, fmapCC, cofmapFC, cofmapCF
  -- * Type composition
  -- ** Unary\/binary
  , OO(..)
--   -- * Binary\/unary
--   , ArrowAp(..),
  -- ** (->)\/unary
  , FunA(..), inFunA, inFunA2, FunAble(..)
  -- * Monoid constructors
  , Monoid_f(..)
  -- * Flip a binary constructor's type arguments
  , Flip(..), biFlip, inFlip, inFlip2, inFlip3, OI, ToOI(..)
  -- * Type application
  , (:$)(..), App, biApp, inApp, inApp2
  -- * Identity
  , Id(..), biId, inId
  -- * Constructor pairing
  -- ** Unary
  , (:*:)(..), biProd, convProd, (***#), ($*), inProd, inProd2, inProd3
  -- * Binary
  , (::*::)(..), inProdd, inProdd2
  -- * Arrow between /two/ constructor applications
  , Arrw(..), (:->:)
  , biFun, convFun, inArrw, inArrw2, inArrw3
  -- * Augment other modules
  , biConst, inConst, inConst2, inConst3
  , biEndo, inEndo
  ) where

import Control.Applicative
import Control.Arrow hiding (pure)
import Data.Monoid

-- import Test.QuickCheck -- for Endo

import Data.Bijection

infixl 9 :. -- , `O`
infixl 7 :*:
infixr 1 :->:
infixr 0 :$

infixl 0 $*
infixr 3 ***#

{----------------------------------------------------------
    Misc
----------------------------------------------------------}

-- |Unary functions
type Unop  a = a -> a
-- |Binary functions
type Binop a = a -> a -> a


{----------------------------------------------------------
    Contravariant functors
----------------------------------------------------------}

-- | Contravariant functors.  often useful for /acceptors/ (consumers,
-- sinks) of values.
class Cofunctor acc where
  cofmap :: (a -> b) -> (acc b -> acc a)

-- | Bijections on contravariant functors
bicomap :: Cofunctor f => (a :<->: b) -> (f a :<->: f b)
bicomap (Bi ab ba) = Bi (cofmap ba) (cofmap ab)

{----------------------------------------------------------
    Type composition
----------------------------------------------------------}

{- |

Composition of unary type constructors

There are (at least) two useful 'Monoid' instances, so you'll have to
pick one and type-specialize it (filling in all or parts of @g@ and\/or @f@).

@
    -- standard Monoid instance for Applicative applied to Monoid
    instance (Applicative (g :. f), Monoid a) => Monoid ((g :. f) a) where
      { mempty = pure mempty; mappend = liftA2 mappend }
    -- Especially handy when g is a Monoid_f.
    instance Monoid (g (f a)) => Monoid ((g :. f) a) where
      { mempty = O mempty; mappend = inO2 mappend }
@

Corresponding to the first and second definitions above,

@
    instance (Applicative g, Monoid_f f) => Monoid_f (g :. f) where
      { mempty_f = O (pure mempty_f); mappend_f = inO2 (liftA2 mappend_f) }
    instance Monoid_f g => Monoid_f (g :. f) where
      { mempty_f = O mempty_f; mappend_f = inO2 mappend_f }
@

Similarly, there are two useful 'Functor' instances and two useful
'Cofunctor' instances.

@
    instance (  Functor g,   Functor f) => Functor (g :. f) where fmap = fmapFF
    instance (Cofunctor g, Cofunctor f) => Functor (g :. f) where fmap = fmapCC
@

@
    instance (Functor g, Cofunctor f) => Cofunctor (g :. f) where cofmap = cofmapFC
    instance (Cofunctor g, Functor f) => Cofunctor (g :. f) where cofmap = cofmapCF
@

However, it's such a bother to define the Functor instances per
composition type, I've left the fmapFF case in.  If you want the fmapCC
one, you're out of luck for now.  I'd love to hear a good solution.  Maybe
someday Haskell will do Prolog-style search for instances, subgoaling the
constraints, rather than just matching instance heads.

-}
newtype (g :. f) a = O { unO :: g (f a) }

-- | Compatibility synonym for ('O')
type O = (:.)

-- Here it is, as promised.
instance (  Functor g,   Functor f) => Functor (g :. f) where fmap = fmapFF

-- | @newtype@ bijection
biO :: g (f a) :<->: (g :. f) a
biO = Bi O unO

-- | Compose a bijection, Functor style
convO :: Functor g => (b :<->: g c) -> (c :<->: f a) -> (b :<->: (g :. f) a)
convO biG biF = biG >>> bimap biF >>> Bi O unO

-- | Compose a bijection, Cofunctor style
coconvO :: Cofunctor g => (b :<->: g c) -> (c :<->: f a) -> (b :<->: (g :. f) a)
coconvO biG biF = biG >>> bicomap biF >>> Bi O unO


-- | Apply a unary function within the 'O' constructor.
inO :: (g (f a) -> g' (f' a')) -> ((g :. f) a -> (g' :. f') a')
inO = (O .).(. unO)

-- | Apply a binary function within the 'O' constructor.
inO2 :: (g (f a)   -> g' (f' a')   -> g'' (f'' a''))
     -> ((g :. f) a -> (g' :. f') a' -> (g'' :. f'') a'')
inO2 h (O gfa) = inO (h gfa)

-- | Apply a ternary function within the 'O' constructor.
inO3 :: (g (f a)   -> g' (f' a')   -> g'' (f'' a'')   -> g''' (f''' a'''))
     -> ((g :. f) a -> (g' :. f') a' -> (g'' :. f'') a'' -> (g''' :. f''') a''')
inO3 h (O gfa) = inO2 (h gfa)

-- | Used for the @Functor :. Functor@ instance of 'Functor'
fmapFF :: (  Functor g,   Functor f) => (a -> b) -> (g :. f) a -> (g :. f) b
fmapFF h = inO $ fmap (fmap h)

-- | Used for the @Cofunctor :. Cofunctor@ instance of 'Functor'
fmapCC :: (Cofunctor g, Cofunctor f) => (a -> b) -> (g :. f) a -> (g :. f) b
fmapCC h = inO $ cofmap (cofmap h)

-- | Used for the @Functor :. Cofunctor@ instance of 'Functor'
cofmapFC :: (Functor g, Cofunctor f) => (b -> a) -> (g :. f) a -> (g :. f) b
cofmapFC h (O gf) = O (fmap (cofmap h) gf)

-- | Used for the @Cofunctor :. Functor@ instance of 'Functor'
cofmapCF :: (Cofunctor g, Functor f) => (b -> a) -> (g :. f) a -> (g :. f) b
cofmapCF h (O gf) = O (cofmap (fmap h) gf)

instance ( Functor (g :. f)
         , Applicative g, Applicative f) => Applicative (g :. f) where
  pure x            = O (pure (pure x))
  O getf <*> O getx = O (liftA2 (<*>) getf getx)


{----------------------------------------------------------
    Unary\/binary composition
----------------------------------------------------------}

-- | Composition of type constructors: unary with binary.  Called
-- "StaticArrow" in [1].
newtype OO f (~>) a b = OO { unOO :: f (a ~> b) }

instance (Applicative f, Arrow (~>)) => Arrow (OO f (~>)) where
  arr           = OO . pure . arr
  OO g >>> OO h = OO (liftA2 (>>>) g h)
  first (OO g)  = OO (liftA first g)

-- For instance, /\ a b. f (a -> m b) =~ OO f Kleisli m

{-

{----------------------------------------------------------
    Binary\/unary composition.  * Not currently exported *
----------------------------------------------------------}

-- | Composition of type constructors: binary with unary.  See also
-- 'FunA', which specializes from arrows to functions.
-- 
-- Warning: Wolfgang Jeltsch pointed out a problem with these definitions:
-- 'splitA' and 'mergeA' are not inverses.  The definition of 'first',
-- e.g., violates the \"extension\" law and causes repeated execution.
-- Look for a reformulation or a clarification of required properties of
-- the applicative functor @f@.
-- 
-- See also "Arrows and Computation", which notes that the following type
-- is "almost an arrow" (<http://www.soi.city.ac.uk/~ross/papers/fop.html>).
-- 
-- @
--   newtype ListMap i o = LM ([i] -> [o])
-- @

newtype ArrowAp (~>) f a b = ArrowAp {unArrowAp :: f a ~> f b}

instance (Arrow (~>), Applicative f) => Arrow (ArrowAp (~>) f) where
  arr                     = ArrowAp . arr . liftA
  ArrowAp g >>> ArrowAp h = ArrowAp (g >>> h)
  first (ArrowAp a)       =
    ArrowAp (arr splitA >>> first a >>> arr mergeA)

instance (ArrowLoop (~>), Applicative f) => ArrowLoop (ArrowAp (~>) f) where
  -- loop :: UI (b,d) (c,d) -> UI b c
  loop (ArrowAp k) =
    ArrowAp (loop (arr mergeA >>> k >>> arr splitA))

mergeA :: Applicative f => (f a, f b) -> f (a,b)
mergeA ~(fa,fb) = liftA2 (,) fa fb

splitA :: Applicative f => f (a,b) -> (f a, f b)
splitA fab = (liftA fst fab, liftA snd fab)

-}


{----------------------------------------------------------
    (->)\/unary composition
----------------------------------------------------------}

-- Hm.  See warning above for 'ArrowAp'

-- | Common pattern for 'Arrow's.
newtype FunA h a b = FunA { unFunA :: h a -> h b }

-- | Apply unary function in side a 'FunA' representation.
inFunA :: ((h a -> h b) -> (h' a' -> h' b'))
       -> (FunA h a b -> FunA h' a' b')
inFunA = (FunA .).(. unFunA)

-- | Apply binary function in side a 'FunA' representation.
inFunA2 :: ((h a -> h b) -> (h' a' -> h' b') -> (h'' a'' -> h'' b''))
       -> (FunA h a b -> FunA h' a' b' -> FunA h'' a'' b'')
inFunA2 q (FunA f) = inFunA (q f)

-- | Support needed for a 'FunA' to be an 'Arrow'.
class FunAble h where
  arrFun    :: (a -> b) -> (h a -> h b) -- ^ for 'arr'
  firstFun  :: (h a -> h a') -> (h (a,b) -> h (a',b)) -- for 'first'
  secondFun :: (h b -> h b') -> (h (a,b) -> h (a,b')) -- for 'second'
  (***%)    :: (h a -> h b) -> (h a' -> h b') -> (h (a,a') -> h (b,b')) -- for '(***)'
  (&&&%)    :: (h a -> h b) -> (h a  -> h b') -> (h a -> h (b,b')) -- for '(&&&)'

  -- In direct imitation of Arrow defaults:
  f ***% g = firstFun f >>> secondFun g
  f &&&% g = arrFun (\b -> (b,b)) >>> f ***% g

instance FunAble h => Arrow (FunA h) where
  arr p  = FunA    (arrFun p)
  (>>>)  = inFunA2 (>>>)
  first  = inFunA  firstFun
  second = inFunA  secondFun
  (***)  = inFunA2 (***%)
  (&&&)  = inFunA2 (&&&%)



{----------------------------------------------------------
    Monoid constructors
----------------------------------------------------------}

-- | Simulates universal constraint @forall a. Monoid (f a)@.
-- 
-- See Simulating Quantified Class Constraints
-- (<http://flint.cs.yale.edu/trifonov/papers/sqcc.pdf>)
--  Instantiate this schema wherever necessary:
--
-- @
--   instance Monoid_f f where { mempty_f = mempty ; mappend_f = mappend }
-- @
class Monoid_f m where
  mempty_f  :: forall a. m a
  mappend_f :: forall a. m a -> m a -> m a

--  e.g.,
instance Monoid_f [] where { mempty_f = mempty ; mappend_f = mappend }



{----------------------------------------------------------
    Flip a binary constructor's type arguments
----------------------------------------------------------}

-- | Flip type arguments
newtype Flip (~>) b a = Flip { unFlip :: a ~> b }

-- | @newtype@ bijection
biFlip :: (a ~> b) :<->: Flip (~>) b a
biFlip = Bi Flip unFlip

-- Apply unary function inside of a 'Flip' representation.
inFlip :: ((a~>b) -> (a' ~~> b')) -> (Flip (~>) b a -> Flip (~~>) b' a')
inFlip = (Flip .).(. unFlip)

-- Apply binary function inside of a 'Flip' representation.
inFlip2 :: ((a~>b) -> (a' ~~> b') -> (a'' ~~~> b''))
        -> (Flip (~>) b a -> Flip (~~>) b' a' -> Flip (~~~>) b'' a'')
inFlip2 f (Flip ar) = inFlip (f ar)

-- Apply ternary function inside of a 'Flip' representation.
inFlip3 :: ((a~>b) -> (a' ~~> b') -> (a'' ~~~> b'') -> (a''' ~~~~> b'''))
        -> (Flip (~>) b a -> Flip (~~>) b' a' -> Flip (~~~>) b'' a'' -> Flip (~~~~>) b''' a''')
inFlip3 f (Flip ar) = inFlip2 (f ar)

instance Arrow (~>) => Cofunctor (Flip (~>) b) where
  cofmap h (Flip f) = Flip (arr h >>> f)

-- Useful for (~>) = (->).  Maybe others.
instance (Applicative ((~>) a), Monoid o) => Monoid (Flip (~>) o a) where
  mempty  = Flip (pure mempty)
  mappend = inFlip2 (liftA2 mappend)

-- TODO: generalize (->) to (~>) with Applicative_f (~>)
instance Monoid o => Monoid_f (Flip (->) o) where
  { mempty_f = mempty ; mappend_f = mappend }

-- | (-> IO ()) as a 'Flip'.  A Cofunctor.
type OI = Flip (->) (IO ())

-- | Convert to an 'OI'.
class ToOI sink where toOI :: sink b -> OI b

instance ToOI OI where toOI = id

{----------------------------------------------------------
    Type application
----------------------------------------------------------}

-- | Type application
-- We can also drop the @App@ constructor, but then we overlap with many
-- other instances, like @[a]@.  Here's a template for @App@-free
-- instances.
-- 
-- @
--   instance (Applicative f, Monoid a) => Monoid (f a) where
--     mempty  = pure mempty
--     mappend = liftA2 mappend
-- @
newtype f :$ a = App { unApp :: f a }

-- | Compatibility synonym for (:$).
type App = (:$)

-- How about?
-- data f :$ a = App { unApp :: f a }

-- | @newtype@ bijection
biApp :: f a :<->: App f a
biApp = Bi App unApp

-- Apply unary function inside of an 'App representation.
inApp :: (f a -> f' a') -> (App f a -> App f' a')
inApp = (App .).(. unApp)

-- Apply binary function inside of a 'App' representation.
inApp2 :: (f a -> f' a' -> f'' a'') -> (App f a -> App f' a' -> App f'' a'')
inApp2 h (App fa) = inApp (h fa)

-- Example: App IO ()
instance (Applicative f, Monoid m) => Monoid (App f m) where
  mempty  =   App  (pure   mempty )
  mappend = inApp2 (liftA2 mappend)

--  App a `mappend` App b = App (liftA2 mappend a b)


{----------------------------------------------------------
    Identity -- TODO: eliminate in favor of Data.Traversable.Id
----------------------------------------------------------}

-- | Identity type constructor.  Until there's a better place to find it.
-- I'd use "Control.Monad.Identity", but I don't want to introduce a
-- dependency on mtl just for Id.
newtype Id a = Id { unId :: a }

inId :: (a -> b) -> (Id a -> Id b)
inId = (Id .).(. unId)

-- | @newtype@ bijection
biId :: a :<->: Id a
biId = Bi Id unId


{----------------------------------------------------------
    Unary constructor pairing
----------------------------------------------------------}

-- | Pairing of unary type constructors
newtype (f :*: g) a = Prod { unProd :: (f a, g a) }
  -- deriving (Show, Eq, Ord)

-- | @newtype@ bijection
biProd :: (f a, g a) :<->: (f :*: g) a
biProd = Bi Prod unProd

-- | Compose a bijection
convProd :: (b :<->: f a) -> (c :<->: g a) -> (b,c) :<->: (f :*: g) a
convProd biF biG = biF *** biG >>> Bi Prod unProd

-- In GHC 6.7, deriving no longer works on types like :*:.  Take out the
-- following three instances when deriving works again, in GHC 6.8.

instance (Show (f a, g a)) => Show ((f :*: g) a) where
  show (Prod p) = "Prod " ++ show p

instance (Eq (f a, g a)) => Eq ((f :*: g) a) where
  Prod p == Prod q = p == q

instance (Ord (f a, g a)) => Ord ((f :*: g) a) where
  Prod p <= Prod q = p <= q
  Prod p `compare` Prod q = p `compare` q

-- | Apply unary function inside of @f :*: g@ representation.
inProd :: ((f a, g a) -> (f' a', g' a'))
       -> ((f :*: g) a -> (f' :*: g') a')
inProd = (Prod .).(. unProd)

-- | Apply binary function inside of @f :*: g@ representation.
inProd2 :: ((f a, g a) -> (f' a', g' a') -> (f'' a'', g'' a''))
        -> ((f :*: g) a -> (f' :*: g') a' -> (f'' :*: g'') a'')
inProd2 h (Prod p) = inProd (h p)

-- | Apply ternary function inside of @f :*: g@ representation.
inProd3 :: ((f a, g a) -> (f' a', g' a') -> (f'' a'', g'' a'')
                       -> (f''' a''', g''' a'''))
        -> ((f :*: g) a -> (f' :*: g') a' -> (f'' :*: g'') a''
                        -> (f''' :*: g''') a''')
inProd3 h (Prod p) = inProd2 (h p)

-- | A handy combining form.  See '(***#)' for an sample use.
($*) :: (a -> b, a' -> b') -> (a,a') -> (b,b')
($*) = uncurry (***)

-- | Combine two binary functions into a binary function on pairs
(***#) :: (a -> b -> c) -> (a' -> b' -> c')
       -> (a, a') -> (b, b') -> (c, c')
h ***# h' = \ as bs -> (h,h') $* as $* bs
            -- (uncurry (***)) . (h *** h')
            -- \ as bs -> uncurry (***) ((h *** h') as) bs
            -- \ as bs -> (h *** h') as $* bs
            -- \ (a,a') (b,b') -> (h a b, h' a' b')

-- instance (Monoid a, Monoid b) => Monoid (a,b) where
-- 	mempty = (mempty, mempty)
-- 	mappend = mappend ***# mappend

instance (Monoid_f f, Monoid_f g) => Monoid_f (f :*: g) where
  mempty_f  = Prod (mempty_f,mempty_f)
  mappend_f = inProd2 (mappend_f ***# mappend_f)

instance (Functor f, Functor g) => Functor (f :*: g) where
  fmap h = inProd (fmap h *** fmap h)


{----------------------------------------------------------
    Binary constructor pairing
----------------------------------------------------------}

-- | Pairing of binary type constructors
newtype (f ::*:: g) a b = Prodd { unProdd :: (f a b, g a b) }
  -- deriving (Show, Eq, Ord)

-- Remove the next three when GHC can derive them (6.8).

instance (Show (f a b, g a b)) => Show ((f ::*:: g) a b) where
  show (Prodd p) = "Prod " ++ show p

instance (Eq (f a b, g a b)) => Eq ((f ::*:: g) a b) where
  Prodd p == Prodd q = p == q

instance (Ord (f a b, g a b)) => Ord ((f ::*:: g) a b) where
  Prodd p < Prodd q = p < q

-- | Apply binary function inside of @f :*: g@ representation.
inProdd :: ((f a b, g a b) -> (f' a' b', g' a' b'))
        -> ((f ::*:: g) a b -> (f' ::*:: g') a' b')
inProdd = (Prodd  .).(. unProdd)

-- | Apply binary function inside of @f :*: g@ representation.
inProdd2 :: ((f a b, g a b) -> (f' a' b', g' a' b') -> (f'' a'' b'', g'' a'' b''))
         -> ((f ::*:: g) a b -> (f' ::*:: g') a' b' -> (f'' ::*:: g'') a'' b'')
inProdd2 h (Prodd p) = inProdd (h p)

instance (Arrow f, Arrow f') => Arrow (f ::*:: f') where
  arr    = Prodd .  (arr    &&&  arr   )
  (>>>)  = inProdd2 ((>>>)  ***# (>>>) )
  first  = inProdd  (first  ***  first )
  second = inProdd  (second ***  second)
  (***)  = inProdd2 ((***)  ***# (***) )
  (&&&)  = inProdd2 ((&&&)  ***# (&&&) )


{----------------------------------------------------------
    Arrow between /two/ constructor applications
----------------------------------------------------------}

-- | Arrow-like type between type constructors (doesn't enforce @Arrow
-- (~>)@ here).
newtype Arrw (~>) f g a = Arrw { unArrw :: f a ~> g a } -- deriving Monoid

deriving instance Monoid (f a ~> g a) => Monoid (Arrw (~>) f g a)

-- Replace with generalized bijection?

-- toArrw :: Arrow (~>) => (f a ~> b) -> (c ~> g a) -> ((b ~> c) -> Arrw (~>) f g a)
-- toArrw fromF toG h = Arrw (fromF >>> h >>> toG)

-- fromArrw :: Arrow (~>) => (b ~> f a) -> (g a ~> c) -> (Arrw (~>) f g a -> (b ~> c))
-- fromArrw toF fromG (Arrw h') = toF >>> h' >>> fromG

-- | Apply unary function inside of @Arrw@ representation.
inArrw :: ((f a ~> g a) -> (f' a' ~> g' a'))
       -> ((Arrw (~>) f g) a -> (Arrw (~>) f' g') a')
inArrw = (Arrw .).(. unArrw)

-- | Apply binary function inside of @Arrw (~>) f g@ representation.
inArrw2 :: ((f a ~> g a) -> (f' a' ~> g' a') -> (f'' a'' ~> g'' a''))
        -> (Arrw (~>) f g a -> Arrw (~>) f' g' a' -> Arrw (~>) f'' g'' a'')
inArrw2 h (Arrw p) = inArrw (h p)

-- | Apply ternary function inside of @Arrw (~>) f g@ representation.
inArrw3 :: ((f a ~> g a) -> (f' a' ~> g' a') -> (f'' a'' ~> g'' a'') -> (f''' a''' ~> g''' a'''))
        -> ((Arrw (~>) f g) a -> (Arrw (~>) f' g') a' -> (Arrw (~>) f'' g'') a'' -> (Arrw (~>) f''' g''') a''')
inArrw3 h (Arrw p) = inArrw2 (h p)

-- Functor & Cofunctor instances.  Beware use of 'arr', which is not
-- available for some of my favorite arrows.

instance (Arrow (~>), Cofunctor f, Functor g) => Functor (Arrw (~>) f g) where
  fmap h = inArrw $ \ fga -> arr (cofmap h) >>> fga >>> arr (fmap h)

instance (Arrow (~>), Functor f, Cofunctor g) => Cofunctor (Arrw (~>) f g) where
  cofmap h = inArrw $ \ fga -> arr (fmap h) >>> fga >>> arr (cofmap h)

-- Restated,
-- 
--   cofmap h = inArrw $ (arr (fmap h) >>>) . (>>> arr (cofmap h))

-- 'Arrw' specialized to functions.  
type (:->:) = Arrw (->)

-- | @newtype@ bijection
biFun :: (f a -> g a) :<->: (f :->: g) a
biFun = Bi Arrw unArrw

-- | Compose a bijection
convFun :: (b :<->: f a) -> (c :<->: g a) -> ((b -> c) :<->: (f :->: g) a)
convFun bfa cga = (bfa ---> cga) >>> biFun

-- biA :: ((f a -> g a) :<->: (f :->: g) a)
-- biA = Bi Arrw unArrw


{----------------------------------------------------------
    Augment other modules
----------------------------------------------------------}

---- For Control.Applicative Const

-- newtype Const a b = Const { getConst :: a }

-- | @newtype@ bijection
biConst :: a :<->: Const a b
biConst = Bi Const getConst

inConst :: (a -> b) -> Const a u -> Const b v
inConst = (Const .).(. getConst)

inConst2 :: (a -> b -> c) -> Const a u -> Const b v -> Const c w
inConst2 f (Const a) = inConst (f a)

inConst3 :: (a -> b -> c -> d)
         -> Const a u -> Const b v -> Const c w -> Const  d x
inConst3 f (Const a) = inConst2 (f a)


---- For Control.Applicative.Endo

-- deriving instance Monoid o => Monoid (Const o a)
instance Monoid o => Monoid (Const o a) where
  mempty  = Const mempty
  mappend = inConst2 mappend

-- newtype Endo a = Endo { appEndo :: a -> a }

-- | @newtype@ bijection
biEndo :: (a -> a) :<->: Endo a
biEndo = Bi Endo appEndo

instance Monoid_f Endo where { mempty_f = mempty; mappend_f = mappend }

-- | Convenience for partial-manipulating functions
inEndo :: (Unop a -> Unop a') -> (Endo a -> Endo a')
inEndo f = Endo . f . appEndo

-- -- | Dual for 'inEndo'
-- outEndo :: (Endo a -> Endo a') -> ((a->a) -> (a'->a'))
-- outEndo g = appEndo . g . Endo

-- -- Missing from Control.Applicative
-- instance Arbitrary a => Arbitrary (Endo a) where
--   arbitrary   = fmap Endo arbitrary
--   coarbitrary = coarbitrary . appEndo

-- -- Simple show instance.  Better: show an arbitrary sampling of the function.
-- instance Show (Endo a) where show _ = "Endo <function>"

