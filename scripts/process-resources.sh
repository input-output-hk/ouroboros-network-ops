#! /usr/bin/env nix-shell
#! nix-shell -p "haskellPackages.ghcWithPackages (pkgs: with pkgs; [split time])" -i runhaskell

import System.Environment
import Data.List.Split
import Data.Bifunctor
import Data.Time.Clock
import Data.Time.Clock.POSIX

main :: IO ()
main = do
  [file] <- getArgs
  contents <- unzip
            . map (toTuple . splitOn ",")
            . lines
          <$> readFile file
  let processedContents = bimap (map (posixSecondsToUTCTime . fromIntegral))
                                (map toGB)
                                contents
      finalResult = uncurry (zipWith (\a b -> show a ++ "," ++ show b))
                            processedContents

  putStrLn (unlines finalResult)

toGiB :: Int -> Int
toGiB = (`div` 1024)
      . (`div` 1024)
      . (`div` 1024)

toTuple :: [String] -> (Int, Int)
toTuple [a,b] = (read a, read b)
toTuple l     = error ("toTuple: list with more than 2 elements: " ++ show l)

