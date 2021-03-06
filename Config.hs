{-# LANGUAGE CPP #-}
#if PRODUCTION
{-# LANGUAGE Safe #-}
#endif

-- | This module exports the gitstar ssh server API location and
-- authorization. It is important that the real file not be added
-- to the git repo
module Config ( gitstar_ssh_web_url
              , gitstar_ssh_web_authorization ) where

import qualified Data.ByteString.Char8 as S8
import qualified Data.ByteString.Base64 as B64

-- | Url to the gitstar ssh API server
gitstar_ssh_web_url :: String
gitstar_ssh_web_url = "http://localhost:9292/"

-- | Authorization for accessing server
gitstar_ssh_web_authorization :: S8.ByteString
gitstar_ssh_web_authorization = S8.pack "Basic " `S8.append`
                                B64.encode (S8.pack "gitstar:w00t")
