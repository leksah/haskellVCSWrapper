-----------------------------------------------------------------------------
--
-- Module      :  VCSWrapper.Git
-- Copyright   :  Copyright (C) 2009-2010 Vincent Hanquez
-- License     :  AllRightsReserved
--
--   Maintainer  : Vincent Hanquez <vincent@snarc.org>, modified Harald Jagenteufel
-- Stability   :  experimental
-- Portability :
--
-- | This module provide Git functionality exec'ing the git binary.
-- give simple access to commit, checkout, status, log.
-----------------------------------------------------------------------------

module VCSWrapper.Git (
    initDB
    , add
    , rm
    , commit
    , checkout
    , status
    , simpleLog
    , localBranches
    , revparse
    , remote
    , pull
    , push
    --    , clone

    , module VCSWrapper.Git.Process -- TODO only export useful process functions

    , module VCSWrapper.Git.Types
) where

import System.Directory
import Control.Monad.Trans
import Data.List.Utils

import VCSWrapper.Git.Parsers
import VCSWrapper.Git.Process
import VCSWrapper.Git.Types

import Data.Maybe
import qualified Data.List
import Data.String.Utils (strip)


{- | initialize a new repository database -}
initDB :: Bool -> Ctx ()
initDB bare = do
    let opts = if bare then ["--bare"] else []
    gitExecWithoutResult "init-db" opts []

{- | add filepath to repository -}
add :: [ FilePath ] -> Ctx ()
add paths = do
    let opts = "--" : paths
    gitExecWithoutResult "add" opts []

{- | rm filepath from repository -}
rm :: [ FilePath ] -> Ctx ()
rm paths = do
    let opts = "--" : paths
    gitExecWithoutResult "rm" opts []

{- | commit change to the repository with optional filepaths and optional author + email -}
commit :: [ FilePath ] -> Maybe (String, String) -> String -> [String] -> Ctx ()
commit rsrcs mbAuthor logmsg extraopts = do
        case mbAuthor of
            Just (author, author_email) ->
                commit' rsrcs logmsg extraopts ["--author", author ++ " <" ++ author_email ++ ">"]
            Nothing ->
                commit' rsrcs logmsg extraopts []
    where
    commit' files logmsg extraopts authopts = do
        let msgopts = [ "-m", logmsg ]
        let opts = authopts ++ msgopts ++ extraopts ++ [ "--" ] ++ files
        gitExecWithoutResult "commit" opts []

{- | checkout the index to some commit id creating potentially a branch -}
checkout :: Maybe String -- ^ Commit ID
        -> Maybe String -- ^ branchname
        -> Ctx ()
checkout rev branch = do
    let bopt = maybe [] (\b -> [ "-b", b ]) branch
    let copt = maybeToList rev -- [] (: []) rev
    gitExecWithoutResult "checkout" (bopt ++ copt) []


---------------------------------
-- modification Harald Jagenteufel
---------------------------------

    -- | Return the status of given repo.
status :: Ctx [Status]
status = do
    rawStatus <- gitExec "status" ["--porcelain"] []
    case rawStatus of
        Left err -> vcsError err "status"
        Right status -> return $ parseStatus status

-- | get the log, maybe from a specific branch (defaults to the current branch)
simpleLog :: Maybe String -> Ctx [LogEntry]
simpleLog mbBranch = do
        rawLog <- gitExec "log" ((branch mbBranch) ++ ["--pretty=tformat:commit:%H%n%an%n%ae%n%ai%n%s%n%b%x00", "--"]) [] -- double dash on end prevent crash if branch and filename are equal
        case rawLog of
            Left err -> vcsError err "log"
            Right log -> do
                return $ parseSimpleLog log
    where
    branch Nothing = []
    branch (Just b) = [b]


-- | get all local branches.
localBranches :: Ctx (String, -- ^ currently checked out branch
     [String]) -- ^ all other branches
localBranches = do
    rawBranches <- gitExec "branch" [] []
    case rawBranches of
        Left err -> vcsError err "branch"
        Right branches -> do
            return $ parseBranches branches

-- | get all remotes
remote :: Ctx [String]
remote = do
    rawRemotes <- gitExec "remote" [] []
    case rawRemotes of
        Left err -> vcsError err "remote"
        Right remotes -> return $ parseRemotes remotes

-- | push changes to another repository
push :: Ctx ()
push = gitExecWithoutResult "push" [] []

-- | pull changes from a remote
pull :: Ctx ()
pull = gitExecWithoutResult "pull" [] []

-- | call git rev-parse on a given commit
revparse :: String -> Ctx (String)
revparse commit = do
    o <- gitExec "rev-parse" [commit] []
    case o of
        Left err -> vcsError err "rev-parse"
        Right out -> return $ strip out






