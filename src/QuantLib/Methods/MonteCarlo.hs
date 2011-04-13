{-# LANGUAGE MultiParamTypeClasses, FunctionalDependencies, BangPatterns #-}
module QuantLib.Methods.MonteCarlo
        ( module QuantLib.Methods.MonteCarlo
        ) where

import Control.Monad
import Control.Parallel.Strategies
import QuantLib.Stochastic.Process
import QuantLib.Stochastic.Random

-- | Summary type class aggregates all priced values of paths
class PathPricer p => Summary m p | m->p where
        -- | Updates summary with given priced pathes
        sSummarize      :: m->[p]->m
        -- | Defines a metric, i.e. calculate distance between 2 summaries
        sNorm           :: m->m->Double

-- | Path generator is a stochastic path generator
class PathGenerator m where
        pgGenerate      :: m->IO Path

-- | Path pricer provides a price for given path
class PathPricer m where
        ppPrice         :: m->Path->m


-- | Monte Carlo engine function
monteCarlo :: (Summary s p, PathPricer p, PathGenerator g) => PathMonteCarlo s p g->Int->IO s
monteCarlo (PathMonteCarlo s p g) size = do
        priced <- mapM (\_ -> pricing) [1..size]
        return $ sSummarize s priced
        where   pricing = do
                        !path <- pgGenerate g
                        return $! ppPrice p path

monteCarloParallel :: (Summary s p, PathPricer p, PathGenerator g) => PathMonteCarlo s p g->Int->IO s
monteCarloParallel (PathMonteCarlo s p g) size = do
        priced <- mapM (\_ -> pricing) [1..size] `using` rpar
        return $ sSummarize s priced
        where   pricing = do
                        !path <- pgGenerate g
                        return $! ppPrice p path

priced :: (PathGenerator m, PathPricer b, Num a, Enum a) =>b -> m -> a -> IO [b]
priced p g size = mapM (\_ -> pricing) [1..size] `using` strat
        where   pricing = do
                        !path <- pgGenerate g
                        return $! ppPrice p path
                strat   = rpar



-- | Path-dependant Monte Carlo engine
data (Summary s p, PathPricer p, PathGenerator g) => PathMonteCarlo s p g
        = PathMonteCarlo {
                pmcSummary      :: s,
                pmcPricer       :: p,
                pmcGenerator    :: g
                }

-- | This pricer gets the last point of path
data LastPointPricer = LastPointPricer Dot

instance PathPricer LastPointPricer where
        ppPrice _ path = LastPointPricer (last path) 

-- | Stochastic process generator
data (StochasticProcess sp, NormalGenerator b, Discretize d) => ProcessGenerator sp b d 
        = ProcessGenerator {
                pgStart         :: Dot,
                pgLength        :: Int,
                pgProcess       :: sp,
                pgGenerator     :: b,
                pgDiscretize    :: d
        }

instance (StochasticProcess sp, NormalGenerator b, Discretize d) => PathGenerator (ProcessGenerator sp b d) where
        pgGenerate (ProcessGenerator start len sp b d) = generatePath b d sp len start

