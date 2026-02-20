# Implement the Lottery of Your Choice
First, pick the exponent base. The higher it is, the more rewarded previous finishes and applications are. The range [2,4] seems reasonable. You don't have to use whole numbers, but it's nice for simplicity.

Second, pick the relative worth of previous finishes to applications. Right now, each finish is worth roughly half a previous application. So the range (0,1] makes sense. In theory you could make finishes worth *more*, but that permanently rewards older people and people who get luckier earlier, even if they start applying to the race at the same time. 
THIS DOESN'T WORK YET

Third, pick the number of previous finishes that provides the maximum boost. (This is the transformation we apply to K.) All runners with more finished are lumped into the same as those with 1 previous finish. Right now it's set to 3. By the formula 4 finishes actually gets you *less* boost than 3. Except that right now everyone with 4 finishes is a legacy runner. So with the 2022 application data, setting this higher won't change anything. Setting it to 1 or 2 does change things.
THIS DOESN'T WORK YET

Fourth, pick the multiplier base for trailwork and volunteering. It's currently 2. The range [1,10] seems reasonable. By design, you really have to yank on this lever to get it to do much.

Fifth, pick the number of women and men to let in. 2022 picked 66 women and 62 men. Obviously, the more the better.