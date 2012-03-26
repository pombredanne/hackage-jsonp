{-# LANGUAGE OverloadedStrings #-}
module Main (
  main

-- exported for testing
, parse
, parseMany
) where

import           Data.Foldable (forM_)
import           System.IO (hPutStrLn, stderr, withFile, IOMode(..))
import           System.Time (getClockTime)
import           Control.Concurrent (threadDelay)
import qualified Data.ByteString.Lazy.Char8 as L
import           Control.Monad.IO.Class
import           Data.Aeson.Generic
import           Data.Conduit
import           Network.HTTP.Types
import           Network.HTTP.Conduit

import           Parse

-- | Output file.
file :: FilePath
file = "hackage-package-versions.jsonp"

-- | URL to Hackage upload log.
uploadLogUrl :: String
uploadLogUrl = "http://hackage.haskell.org/packages/archive/log"

-- | Parse given data, and write it as JSONP.
writeJSONP :: L.ByteString -> IO ()
writeJSONP input = withFile file WriteMode $ \h -> do
  L.hPut h "hackagePackageVersionsCallback("
  L.hPut h (encode . parseMany $ input)
  L.hPut h ");"

-- |
-- Download the Hackage upload log, parse it, and write latest package versions
-- into a JSONP file.
--
-- Repeatedly check if the upload log has changed, and if so, regenerate the
-- JSONP file.
main :: IO ()
main = go ""
  where
    go etag = do
      (e, r) <- update etag
      forM_ r writeJSONP

      -- sleep for 60 seconds
      threadDelay 60000000
      go e

    update :: Ascii -> IO (Ascii, Maybe L.ByteString)
    update etag = withManager $ \manager -> do
      e <- getEtag manager
      if etag == e
        then do
          logInfo "nothing changed"
          return (e, Nothing)
        else do
          logInfo "updating"
          r <- getLog manager
          logInfo "updating done"
          (return . fmap Just) r

-- | Write a log message to stderr.
logInfo :: MonadIO m => String -> m ()
logInfo msg = liftIO $ do
  t <- getClockTime
  hPutStrLn stderr (show t ++ ": " ++ msg)

-- | Get etag of Hackage upload log.
getEtag :: Manager -> ResourceT IO Ascii
getEtag manager = do
  Response _ _ header _ <- httpLbs logRequest {method = "HEAD"} manager
  return (etagHeader header)

-- | Get Hackage upload log.
getLog :: Manager -> ResourceT IO (Ascii, L.ByteString)
getLog manager = do
  Response _ _ header body <- httpLbs logRequest manager
  return (etagHeader header, body)

-- | Get etag from headers.
--
-- Fail with `error`, if there is no etag.
etagHeader :: ResponseHeaders -> Ascii
etagHeader = maybe (error "etagHeader: no etag!") id . lookup "etag"

logRequest :: Request t
logRequest = req {redirectCount = 0}
  where
    req = maybe (error $ "logRequest: invalid URL " ++ show uploadLogUrl) id (parseUrl uploadLogUrl)
