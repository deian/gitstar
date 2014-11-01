{-# LANGUAGE CPP #-}
#if PRODUCTION
{-# LANGUAGE Safe #-}
#endif
{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Controllers.Projects ( projectsController ) where

import Prelude hiding (lookup, show, (++))
import qualified Prelude

import Layouts
import Gitstar.Models
import Gitstar.Policy
import Views.Projects

import LIO


import qualified Data.ByteString.Char8 as S8
import qualified Data.Text as T
import Data.Maybe

import Hails.Data.Hson
import Hails.Database
import Hails.Database.Structured
import Hails.Web.Controller
import Hails.Web.REST
import Hails.Web.Responses

import Utils


projectsController :: RESTController
projectsController = do
  index $ do
    projects <- liftLIO $ withGitstar $
      findAll $ select [] "projects"
    renderHtml $ listProjects projects

  show $ do
    (Just projName) <- queryParam "id"
    muser <- getHailsUser
    (Just uName) <- queryParam "user_name"
    mProj <- withGitstar $ findWhere $
                select [ "name" -: projName
                       , "owner" -: uName ] "projects"
    with404orJust mProj $ \proj -> do
      frkdP <- withGitstar $ findBy "projects" "_id" (projectForkedFrom proj)
      mas <- withGitstar $ mapM (findBy "apps" "_id") (projectApps proj)
      let apps = map fromJust $ filter isJust mas
      atype <- requestHeader "accept"
      case atype of
        Just "application/bson" ->
          respond $ ok "application/bson" $ serialize $ toDocument proj
        _ -> renderHtml $
              showProject muser proj apps frkdP


  edit $ withUserOrDoAuth $ \curUsr -> do
    (Just projName) <- queryParam "id"
    (Just uName) <- queryParam "user_name"
    if curUsr /= (T.pack . S8.unpack $ uName)
      then return forbidden
      else do mProj <- withGitstar $ findWhere $
                          select [ "name" -: projName
                                 , "owner" -: uName ] "projects"
              with404orJust mProj $ \proj -> renderHtml $ editProject proj

  -- /projects/new
  new $ withUserOrDoAuth $ \_ -> renderHtml newProject

  -- Create a new project (from scractch or fork)
  -- TODO: mkProject may throw an exception if the document is not
  -- "well-formed". We can handle this more gracefully.
  create $ withUserOrDoAuth $ \uName -> do
    lreq   <- request
    ldoc <- liftLIO $ labeledRequestToHson lreq
    lproj  <- liftLIO $ mkProject ldoc
    proj   <- liftLIO $ unlabel lproj
    let pOwner = projectOwner proj
        pName  = projectName  proj

    exists <- projExists pOwner pName

    if exists
      then redirectBack -- >> flashError "Project already exists!" 
      else do 
            projId <- withGitstar $ insertLabeledRecord lproj
            updateUserWithProjId uName (Just projId)
            return . redirectTo . T.unpack $ "/" ++ pOwner ++ "/" ++ pName
            --      flashSuccess $ "Project successfully " ++

  update $ withUserOrDoAuth $ \uName -> do
    req <- request
    ldoc <- liftLIO $ labeledRequestToHson req
    doc <- liftLIO $ unlabel ldoc
    projName <- fmap (S8.pack . T.unpack) $ lookup "name" doc
    lproj0  <- liftLIO $ mkProject ldoc
    lproj <- partialProjectUpdate lproj0
    withGitstar $ do
      saveLabeledRecord lproj
    return $ redirectTo $ (T.unpack $ "/" ++ uName ++ "/") ++ (S8.unpack projName)

  where projExists owner projName = withGitstar $ do
          let qry = select ["name" -: projName, "owner" -: owner] "projects"
          mproj <- findWhere qry
          return $ case mproj of
                     (Just (Project {})) -> True
                     _                   -> False

