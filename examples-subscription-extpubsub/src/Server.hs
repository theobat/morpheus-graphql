{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

-- |
-- Module      : Server
-- Description :
--  This module creates a postgresql connection through hasql, a datastructure for events
--  and spawn a dedicated thread listening to postgresql event, and publishing to graphql
--  server events.
module Server where

import Control.Monad.IO.Class (liftIO)
import Data.Functor.Identity (Identity (..))
import Data.Morpheus.Types (
    GQLType (description), RootResolver(..), Undefined(Undefined),
    GQLRequest, GQLResponse,
    Event(Event, channels, content), Stream, Input,
    SUBSCRIPTION, Resolver,
    subscribe
  )
import GHC.Generics (Generic)
import Data.Morpheus (interpreter)
import qualified Network.Wai.Handler.Warp as Warp
import qualified Network.Wai.Handler.WebSockets as WaiWs
import Hasql.Connection (Connection)
import qualified Hasql.Connection as SQLC
import Network.WebSockets (defaultConnectionOptions)
import Web.Scotty
  ( body,
    post,
    raw,
    scottyApp,
  )
import System.IO
  ( BufferMode (LineBuffering),
    hSetBuffering,
    stdout
  )
import Data.Morpheus.Server
  ( httpPubApp,
    webSocketsApp,
  )
import Hasql.Notifications (toPgIdentifier, listen, waitForNotifications)
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8)
import Control.Concurrent (forkIO)

startServer :: IO ()
startServer = do
  hSetBuffering stdout LineBuffering
  scottyServer

scottyServer :: IO ()
scottyServer = do
  putStrLn "init sql connection"
  pgConnectionEither <- SQLC.acquire (SQLC.settings "localhost" 5432 "morpheus_user_test" "p" "morpheus_user_db")
  putStrLn "init websocket app"
  (wsApp, publish) <- webSocketsApp makeAPI  
  case pgConnectionEither of
        Left err -> error ("erreur de connection" <> show err)
        -- spawn postgres observation in a new thread:
        -- be careful with this the connection should not be shared
        -- (as is, it's safe, because it's only used in the new thread)
        Right c -> forkIO (postgresHandler c publish)
  putStrLn "init api"
  httpApp <- app publish
  putStrLn " http listening on port 8888"
  Warp.runSettings (settings 8888) $
    WaiWs.websocketsOr defaultConnectionOptions wsApp httpApp
  where
    settings portNumber = Warp.setPort portNumber Warp.defaultSettings
    app publish = scottyApp $ do
      post "/api" $ do
        raw =<< (liftIO . (httpPubApp makeAPI publish)) =<< body

data EventChannel = PgChannel | RBMQChannel
  deriving (Eq, Show)
data EventContent = Dumbo Text | WhiteRabbit Text
  deriving (Eq, Show)

type AppEvent = Event EventChannel EventContent
rootResolver :: RootResolver IO AppEvent Query Undefined Subscription
rootResolver =
  RootResolver
    { queryResolver = queryInstance,
      mutationResolver = Undefined,
      subscriptionResolver = subscriptionInstance
    }

-- | This part is irrelevant, we only care about showcasing subscriptions, but a 
-- Query instance is mandatory in 'RootResolver'.
data Query m
  = Query {
    someQuery :: m Int 
  }
  deriving (Generic, GQLType)
queryInstance = Query (pure 12) -- random stuff

-- | We create a subscription which simply show an unstructured message.
data Subscription m
  = Subscription
      { listenToPostgres :: m Text
      }
  deriving (Generic, GQLType)

subscriptionInstance :: Subscription (
  Resolver SUBSCRIPTION (Event EventChannel EventContent) IO
  )
subscriptionInstance =
  Subscription
    { listenToPostgres = subscribe [PgChannel] (pure subResolver)
    }
    where
      subResolver (Event [PgChannel] (Dumbo _value)) = pure _value
      subResolver _ = error "This should never execute"


makeAPI :: Input api -> Stream api AppEvent IO
makeAPI = interpreter rootResolver

-- | This is the onEvent callback creator in a dedicated thread.
postgresHandler pgConnection publish = do
  putStrLn "listen to PG"
  listen pgConnection (toPgIdentifier "postgres_channel")
  waitForNotifications (
      -- This is the actual callback of the postgres NOTIFY
      \channel content -> do
        print $ "Just got notification on channel " <> channel
        publish Event {channels = [PgChannel], content = Dumbo (decodeUtf8 content)}
    ) pgConnection