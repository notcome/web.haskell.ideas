# Validatable Form
Generate frontend forms and backend validators with a single piece of code.

## Original Approach
I came up with this idea when developing `bbq.yan.ac`, my first real world web app. At that time, I used typeclass-based polymorphism to achieve it. I defined a typeclass `TypesafeForm` like this:

```Haskell
class TypesafeForm m where
  askEmail    :: String -> Text -> m Email
  askPassword :: String -> Text -> m Password
  askText     :: String -> Text -> m String
  addButton   :: String -> Text -> m ()
  askChoice   :: String -> Text -> [(String, String)] -> m String
  should      :: Bool -> Maybe String -> m ()
```

Inside a `Html` monad (provided by [blaze-html](https://hackage.haskell.org/package/blaze-html)), above functions will write HTML code in order to generate a form. This is easy to implement. But I met some troubles when generating validators. I was unable to add an IO monad layer inside my fragile form system, but IO actions like database queries are required to verify user input. At last, I made a compromise and got a form data extractor.

A form can be defined like this:

```Haskell
loginForm :: (Monad m, TypesafeForm m) => m (Email, Password)
loginForm = do
  email    <- askEmail    "email"    "Email"
  password <- askPassword "password" "Password"
  addButton "submit" "Login"
  return (email, password)
```

## Free Monad + Interpreter Pattern
Recently, I read an interesting [post](http://programmers.stackexchange.com/questions/242795/what-is-the-free-monad-interpreter-pattern) on StackExchange. It’s about implementing DSL inside Haskell.

For example, we have a DSL which can be composed through [continuation-passing style](http://en.wikipedia.org/wiki/Continuation-passing_style):

```Haskell
data DSL next = Get String (String -> next)
              | Set String String next
              | End
```

With the help of free monad, we can write this DSL in a natural way:

```Haskell
aDSL = do foo <- get "foo"
          set "bar" foo
          end
```

`aDSL` is an AST of this little imperative program. We can interpret it however we like, including **doing some IO**! After reading this post, I decided to implement my validatable forms using this design pattern.

## To Be Continued…