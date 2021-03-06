{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

module Feature.Input.DefaultValue.API
  ( api,
    rootResolver,
  )
where

import Data.Morpheus (interpreter)
import Data.Morpheus.Document (importGQLDocument)
import Data.Morpheus.Types
  ( GQLRequest,
    GQLResponse,
    ID (..),
    RootResolver (..),
    Undefined (..),
  )
import Data.Text (Text, pack)

importGQLDocument "test/Feature/Input/DefaultValue/schema.gql"

rootResolver :: RootResolver IO () Query Undefined Undefined
rootResolver =
  RootResolver
    { queryResolver = Query {user, testSimple},
      mutationResolver = Undefined,
      subscriptionResolver = Undefined
    }
  where
    user :: Applicative m => m (Maybe (User m))
    user =
      pure
        $ Just
        $ User
          { inputs = pure . pack . show
          }
    testSimple = pure . pack . show

-----------------------------------
api :: GQLRequest -> IO GQLResponse
api = interpreter rootResolver
