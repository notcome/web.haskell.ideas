{-# LANGUAGE DeriveFunctor             #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE QuasiQuotes               #-}

import Control.Monad.Free
import Data.String.Here
import qualified Data.Char

data ValiDSL a next = Validate Bool ErrorMessage next
                    | Query Key (Result -> next)
                    | Ask InputType String String (Result -> next)
                    | Output a
                    deriving Functor

type ErrorMessage = String
type Key          = String
type Result       = String

data InputType = Email
               | Password
               | Text
               | Choice [(String, String)]

validate cond errMsg = liftF (Validate cond errMsg ())
query key            = liftF (Query    key id)
ask type_ id_ hint   = liftF (Ask      type_ id_ hint id)
output result        = liftF (Output   result)

type ValidatableForm a = Free (ValiDSL a) ()

login :: ValidatableForm String
login = do email   <- ask Email    "email"    "注册邮箱"
           passwd  <- ask Password "password" "账户密码"
           passwd' <- query email
           validate (passwd == passwd') "密码错误"
           output email

-- PersonalInfo = (Name, School, Grade)
type PersonalInfo = (String, String, String)
fillInfo :: ValidatableForm (PersonalInfo, String)
fillInfo = let
    grades  = "社会选手":[a:b:"" | a <- "初高", b <- "一二三"]
    grades' = Choice [(a,a) | a <- grades]
    inRange lo hi val = val >= lo && val <= hi
    isHanChar = inRange 0x4e00 0x9fff . Data.Char.ord
    test lo hi x = all isHanChar x && inRange lo hi (length x)
  in do
    passwd <- ask Password "password" "输入你的密码（12—24 位，任意字符均可）"
    repeat <- ask Password "repeat"   "重复输入你的密码"
    name   <- ask Text     "name"     "输入你的真实姓名，全汉字，不超过六个汉字"
    school <- ask Text     "school"   "输入你的学校的中文全称，全汉字，不超过二十个汉字"
    grade  <- ask grades'  "grade"    "选择你的年级"
    validate (passwd == repeat)   "两次密码输入不一致"
    validate (test 2 6  name)     "姓名格式不正确"
    validate (test 4 20 school)   "校名格式不正确"
    validate (elem grade grades)  "无效的年级信息"
    let info = (name, school, grade)
    output (info, passwd)

printForm :: ValidatableForm a -> IO ()
printForm (Pure _)   = error "Should not be reachable."
printForm (Free dsl) = f dsl
  where
    f (Output _)          = return ()
    f (Validate _ _ next) = printForm next
    f (Query _ next)      = printForm $ next undefined
    f (Ask type_ id_ hint next) = do
      print type_ id_ hint
      printForm $ next undefined

    printType Email    = "email"
    printType Password = "password"
    printType Text     = "text"
    printType _        = error "Something went wrong"

    printChoice (name, text) = do
      putStrLn [i|  <option value="${name}">${text}</option>|]

    print (Choice choices) id_ hint = do
      putStrLn [i|<label for="${id_}">${hint}</label>|]
      putStrLn [i|<select name="${id_}">|]
      sequence $ map printChoice choices
      putStrLn [i|</select>|]

    print type_ id_ hint = do
      putStrLn [i|<label for="${id_}">${hint}</label>|]
      putStrLn [i|<input name="${id_}" type="${printType type_}"/>|]
