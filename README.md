# morpheus-graphql

Build GraphQL APIs with your favourite functional language!

## Hello world GrapqhQL haskell

define schema with native Haskell Types and derive them as GraphQL Schema and Introspection

```haskell

-- Query Arguments
data Location = Location
  { zipCode :: Maybe Int -- Optional Argument
  , name  :: Text -- Required Argument
  } deriving (Show, Data, Generic , GQLArgs)

data User = User
  { name    :: Text  -- pure value
  , email   :: Maybe Text
  , home  :: Location ::-> Address
  } deriving (Show, Data, Generic, GQLKind, GQLObject)

newtype Query = Query
  { user :: () ::-> User -- with IO interaction
  } deriving (Show, Data, Genneric , GQLQuery)


jsonUser :: IO (Either String JSONAddress)
jsonUser = ...

-- Hi Order Resolver
resolveAddress :: User -> Location ::-> Address
resolveAddress = ...

resolveUser :: () ::-> User
resolveUser = Resolver resolve'
  where
    resolve' _ = lift jsonUser >>= eitherToResponse modify
    modify user' =
      User
        { name = "<Name>"
        , email = Just "<Email>"
        , address = resolveAddress user'
        }

resolve :: B.ByteString -> IO GQLResponse
resolve =
  interpreter
    GQLRoot {
      queryResolver = Query {
        user = resolveUser
      },
      mutationResolver = ()
    }
```

## Enum

```haskell
data City
  = Hamburg
  | Paris
  | Berlin
  deriving (Show, Generic, Data, GQLKind , GQLEnum) -- GQL Enum

data SomeGQLType = SomeGQLType
  { ...
    ...
  , city  :: EnumOf City
  } deriving ...

-- pack Enum
SomeGQLType
  { ...
  , city = EnumOf Hamburg
  }

-- unpack Enum
getCity :: SomeGQLType -> City
getCity x = unpackEnum $ city x

```

## Scalar

```haskell

data Odd = Int deriving (Show, Data, Generic, GQLKind)

instance GQLScalar Odd where
  parseValue (Int x) = pure $ Odd (...  )
  parseValue (String x) = pure $ Odd (...  )
  serialize  (Odd value) = Int value

data SomeGQLType = SomeGQLType { ....
 count :: ScalarOf Odd
} deriving ...

```

## InputObject

inputObject can be used only inside in arguments or in another inputObject

```haskell

data Coordinates = Coordinates
{ latitude :: Int
, longitude :: Int
} deriving (Show, Generic, Data, GQLKind, GQLInput)

```

## Descriptions

if you need description for your GQL Type you can define GQL instance manualy and assign them description

```haskell
data Person = Person
{ name :: Text
} deriving (Show, Generic, Data, GQLInput)

instance GQLKind Person where
  description \_ = "ID of Cities in Zip Format"

```

# Mutation

```haskell

newtype Mutation = Mutation
  { createUser :: Form ::-> User
  } deriving (Show, Generic, Data, GQLMutation)

createUser :: Form ::-> User
createUser = ...

resolve :: B.ByteString -> IO GQLResponse
resolve =
  interpreter
    GQLRoot {
      queryResolver = Query {...},
      mutationResolver = Mutation {
        createUser = createUser
      }
    }
```
