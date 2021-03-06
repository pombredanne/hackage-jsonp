{-# LANGUAGE OverloadedStrings #-}
module ParseSpec (main, spec) where

import           Test.Hspec
import           Data.String.Builder
import           Data.String

import           Data.Map   (Map)
import qualified Data.Map as Map
import           Data.ByteString.Lazy.Char8 ()
import           Data.Aeson.Generic

import           Parse

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "encode" $ do
    it "converts a package index to JSON" $ do
      encode (Map.fromList [("foo", "0.1"), ("bar", "0.2"), ("baz", "0.3")] :: Map String String)
        `shouldBe` "{\"foo\":\"0.1\",\"bar\":\"0.2\",\"baz\":\"0.3\"}"

  describe "parse" $ do
    it "parses a line from Hackage upload log" $ do
      parse "Sun Mar 18 05:12:30 UTC 2012 SimonHengel hspec 0.9.2" `shouldBe` ("hspec", "0.9.2")

  describe "parseMany" $ do
    it "parses lines from Hackage upload log" $ do
      parseMany . fromString . build $ do
        "Sun Mar 18 05:12:30 UTC 2012 SimonHengel foo 0.1"
        "Sun Mar 18 05:12:30 UTC 2012 SimonHengel bar 0.2"
        "Sun Mar 18 05:12:30 UTC 2012 SimonHengel baz 0.3"
      `shouldBe` Map.fromList [("foo", "0.1"), ("bar", "0.2"), ("baz", "0.3")]

    it "gives package with higher version number precedence" $ do
      parseMany . fromString . build $ do
        "Sun Mar 18 05:12:30 UTC 2012 SimonHengel hspec 0.0.2"
        "Sun Mar 18 05:12:30 UTC 2012 SimonHengel hspec 0.9.2"
        "Sun Mar 18 05:12:30 UTC 2012 SimonHengel hspec 0.11.0"
        "Sun Mar 18 05:12:30 UTC 2012 SimonHengel hspec 0.0.3"
      `shouldBe` Map.fromList [("hspec", "0.11.0")]
