/* Developed with AI assistance from Claude (Anthropic) -- 20 Jul 2026 */
/* Test timing of array access versus stems */

iterations = 50000
myarray    = .array~new
mystem     = .stem~new
mydotted.  = .stem~new
mywords    = ''

do i=1 to iterations
   myword     = 'Word'i
   myarray[i] = myword
   mydotted.i = myword
   mystem[i]  = myword
   end

mywords = myarray~makestring('LINE', ' ')

start = time('R')
do i = 1 to iterations
   myword = myarray[i]
   end
say iterations 'iterations with array[i]       took' time('R') seconds

start = time('R')
do i = 1 to iterations
   myword = mydotted.i
   end
say iterations 'iterations with stem.i         took' time('R') seconds

start = time('R')
do i = 1 to iterations
   myword = mystem[i]
   end
say iterations 'iterations with stem[i]        took' time('R') seconds

start = time('R')
do w over myarray
   myword = myarray[i]
   end
say iterations 'iterations with w over array   took' time('R') seconds

start = time('R')
do i over myarray~allindexes
   myword = myarray[i]
   end
say iterations 'iterations with i over indexes took' time('R') seconds

start = time('R')
do i over mydotted.
   myword = mydotted.i
   end
say iterations 'iterations with i over stem.   took' time('R') seconds

start = time('R')
do i over mystem
   myword = mystem[i]
   end
say iterations 'iterations with i over stem    took' time('R') seconds

start = time('R')
do w over mywords~makearray(' ')
   myword = w
   end
say iterations 'iterations with w over string  took' time('R') seconds

