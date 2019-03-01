{-# LANGUAGE DeriveGeneric ,DeriveAnyClass , DeriveDataTypeable , OverloadedStrings #-}

module Data.Morpheus.Schema.GQL__Schema where

import           Data.Aeson                     ( ToJSON(..)
                                                , FromJSON(..)
                                                , omitNothingFields
                                                , genericToJSON
                                                , defaultOptions
                                                )
import           GHC.Generics                   ( Generic )
import           Data.Data                      ( Data )
import           Data.Text                      ( Text(..)
                                                , pack
                                                , unpack
                                                )
import           Data.Morpheus.Types.Introspection
                                                ( GQL__Type
                                                , emptyLib
                                                , createType
                                                )
import           Data.Morpheus.Schema.GQL__Directive
                                                ( GQL__Directive )

import           Data.Proxy                     ( Proxy(..) )
import qualified Data.Map                      as M

data GQL__Schema = GQL__Schema {
     types::[GQL__Type]
    , queryType:: Maybe GQL__Type
    , mutationType::Maybe GQL__Type
    , subscriptionType:: Maybe GQL__Type
    , directives:: [GQL__Directive]
} deriving (Show , Data, Generic )

initSchema :: M.Map Text GQL__Type -> GQL__Schema
initSchema types = GQL__Schema
    { types            = M.elems types
    , queryType        = Just $ createType "Query" []
    , mutationType     = Nothing
    , subscriptionType = Nothing
    , directives       = []
    }
