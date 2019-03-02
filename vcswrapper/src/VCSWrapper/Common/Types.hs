{-# LANGUAGE FlexibleInstances, GeneralizedNewtypeDeriving, DeriveDataTypeable #-}
{-# LANGUAGE OverloadedStrings, DeriveGeneric #-}
-----------------------------------------------------------------------------
--
-- Module      :  Common.Types
-- Copyright   :  2011 Stephan Fortelny, Harald Jagenteufel
-- License     :  GPL
--
-- Maintainer  :  stephanfortelny at gmail.com, h.jagenteufel at gmail.com
-- Stability   :
-- Portability :
--
-- | Defines all types and their associated accessorfunctions.
--
-----------------------------------------------------------------------------
module VCSWrapper.Common.Types (
    VCSType(..)
    ,IsLocked
    ,LogEntry (..)
    ,Ctx(..)
    ,Config(..)
    ,Author(..)
    ,VCSException(..)
    ,Status(..)
    ,Modification(..)
    ,makeConfig
    ,makeConfigWithEnvironment
    ,filePath
    ,modification
    ,isLocked
) where

import Control.Applicative (Applicative)
import Control.Exception (Exception)
import Control.Monad.Reader
import Control.Monad.Fail.Compat (MonadFail)
import Data.Aeson (ToJSON, FromJSON)
import Data.Typeable (Typeable)
import Data.Text (Text)
import GHC.Generics (Generic)

-- | Available VCS types implemented in this package.
data VCSType = SVN | GIT | Mercurial
    deriving (Show, Read, Eq, Generic)

instance ToJSON VCSType
instance FromJSON VCSType

-- | Status of a file managed by the respective VCS.
data Status = SVNStatus FilePath Modification IsLocked
    | GITStatus FilePath Modification
    deriving (Show,Read)

-- | Retrieve the 'FilePath' of any VCS 'Status'.
filePath :: Status -> FilePath
filePath (SVNStatus fp _ _) = fp
filePath (GITStatus fp _) = fp

-- | Retrieve the 'Modification' of any VCS 'Status'.
modification :: Status -> Modification
modification (SVNStatus _ m _) = m
modification (GITStatus _ m) = m

-- | Retrieve the 'IsLocked' of any VCS 'Status'. For Git, this returns always 'False'.
isLocked :: Status -> IsLocked
isLocked (SVNStatus _ _ l) = l
isLocked _ = False

-- | Flags to describe the state of a file.
data Modification = None | -- ^ File hasn't been modified.
                    Added | -- ^ File has been selected to be managed by the respective VCS.
                    Conflicting | -- ^ File is in conflicting state. Manually resolving the conflict may be necessary.
                    Deleted | -- ^ File has been deleted.
                    Modified | -- ^ File has been modified since last commit.
                    Replaced | -- ^ File has been replaced by a different file.
                    Untracked | -- ^ File is currently not known by the VCS.
                    Unknown | -- ^ State of file is unknown.
                    Ignored | -- ^ File is ignored by VCS.
                    Missing -- ^ File is missing.
    deriving (Eq,Show,Read)

-- | Represents a log entry in the history managed by the VCS.
data LogEntry = LogEntry {
    mbBranch :: Maybe Text -- ^ Maybe Branchname
    , commitID :: Text -- ^ Commit identifier
    , author :: Text -- ^ Author of this commit.
    , email :: Text -- ^ Email address of the author.
    , date :: Text -- ^ Date this log entry was created.
    , subject :: Text -- ^ Short commit message.
    , body :: Text -- ^ Long body of the commit message.
} deriving (Show)

-- | 'True', if this file is locked by the VCS.
type IsLocked = Bool

-- | Configuration of the 'Ctx' the VCS commands will be executed in.
data Config = Config
    { configCwd :: Maybe FilePath -- ^ Path to the main directory of the repository. E.g. for Git: the directory of the repository containing the @.git@ config directory.
    , configPath :: Maybe FilePath -- ^ Path to the vcs executable. If 'Nothing', the PATH environment variable will be search for a matching executable.
    , configAuthor :: Maybe Author -- ^ Author to be used for different VCS actions. If 'Nothing', the default for the selected repository will be used.
    , configEnvironment :: [(Text, Text)] -- ^ List of environment variables mappings passed to the underlying VCS executable.
    } deriving (Show, Read, Generic)

instance ToJSON Config
instance FromJSON Config

-- | Author to be passed to VCS commands where applicable.
data Author = Author
    { authorName :: Text -- ^ Name of the author.
    , authorEmail :: Maybe Text -- ^ Email address of the author.
    } deriving (Show, Read, Generic)

instance ToJSON Author
instance FromJSON Author

{- | Context for all VCS commands.

    E.g. to create a new Git repository use something like this:

    >import VCSWrapper.Git
    >myInitRepoFn = do
    >    let config = makeConfig "path/to/repo" Nothing Nothing
    >    runVcs config $ initDB False
-}
newtype Ctx a = Ctx (ReaderT Config IO a)
    deriving (Functor, Applicative, Monad, MonadIO, MonadFail, MonadReader Config)

-- | Creates a new 'Config' with a list of environment variables.
makeConfigWithEnvironment :: Maybe FilePath -- ^ Path to the main directory of the repository. E.g. for Git: the directory of the repository containing the @.git@ config directory.
    -> Maybe FilePath -- ^ Path to the vcs executable. If 'Nothing', the PATH environment variable will be search for a matching executable.
    -> Maybe Author -- ^ Author to be used for different VCS actions. If 'Nothing', the default for the selected repository will be used.
    -> [(Text, Text)] -- ^ List of environment variables mappings passed to the underlying VCS executable.
    -> Config
makeConfigWithEnvironment repoPath executablePath author environment = Config {
        configCwd = repoPath
        ,configPath = executablePath
        ,configAuthor = author
        ,configEnvironment = environment
        }
-- | Creates a new 'Config'.
makeConfig :: Maybe FilePath -- ^ Path to the main directory of the repository. E.g. for Git: the directory of the repository containing the @.git@ config directory.
    -> Maybe FilePath -- ^ Path to the vcs executable. If 'Nothing', the PATH environment variable will be search for a matching executable.
    -> Maybe Author -- ^ Author to be used for different VCS actions. If 'Nothing', the default for the selected repository will be used.
    -> Config
makeConfig repoPath executablePath author = Config {
        configCwd = repoPath
        ,configPath = executablePath
        ,configAuthor = author
        ,configEnvironment = []
        }

-- | This 'Exception'-type will be thrown if a VCS command fails unexpectedly.
data VCSException
    -- | Exit code -> stdout -> errout -> 'configCwd' of the 'Config' -> List containing the executed command and its options
    = VCSException Int Text Text FilePath [Text]
    deriving (Show, Typeable)

instance Exception VCSException


