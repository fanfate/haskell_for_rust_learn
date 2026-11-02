main = do
  putStrLn "Hello Haskell"
  putStrLn ("Please look at my odd numbers : " ++ show (filter odd [10 .. 20]))
  print (powerOfX 2 4)

powerOfTwo x = powerOfX x 2

powerOfThree x = powerOfX x 3

powerOfX x y = x ** y
