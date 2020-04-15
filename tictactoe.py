from tictactoe_destroyer import *
from array import array
import timeit
#from matplotlib import interactive
#interactive(True)
import matplotlib.pyplot as plt

#TESTING MAIN PROGRAM: DESTROY
"""
a = array('b', [0 for i in range(81)])
a[40] = 1
a[44] = 2
a[72] = 1
print('t,s = destroy(a, 1000, 72, 2)')
#"""

#TESTING EVALUATE SQUARE
"""
box = array('f', [0 for i in range(90)])
bigState = array('b', [0,0,0,0,0,0,0,0,0])
state = array('b', [1,0,0,0,0,0,0,0,0])
print('evaluateSquare3(state, bigState, box, 0)')
"""

#TESTING EVALUATE POS

pos = array('f', [0 for i in range(18)])
bigState = array('b', [0,0,0,0,0,0,0,0,0])
state = array('b', [1,0,0,0,0,0,0,0,0])
evaluatePosition2(state, bigState, pos, 0)
print('1 corner\n')
state = array('b', [0,2,0,0,0,0,0,0,0])
evaluatePosition2(state, bigState, pos, 0) #1 side
print('1 side\n')
state = array('b', [0,0,0,0,1,0,0,0,0])
evaluatePosition2(state, bigState, pos, 0) #1 centre
print('1 centre\n\n')

state = array('b', [1,1,0,0,0,0,0,0,0])
evaluatePosition2(state, bigState, pos, 0) #2 winning, corner side
print('2 winning, corner side\n')
state = array('b', [0,0,0,0,0,0,2,0,2])
evaluatePosition2(state, bigState, pos, 0) #2 winning, corner corner
print('2 winning, corner corner\n')
state = array('b', [0,2,0,0,2,0,0,0,0])
evaluatePosition2(state, bigState, pos, 0) #2 winning, middle side
print('2 winning, middle side\n')
state = array('b', [0,0,0,0,1,0,1,0,0])
evaluatePosition2(state, bigState, pos, 0) #2 winning, middle corner
print('2 winning, middle corner\n\n')

state = array('b', [1,2,0,0,0,0,0,0,0])
evaluatePosition2(state, bigState, pos, 0) #1-1block corner side
print('1-1block corner side\n')
state = array('b', [2,0,1,0,0,0,0,0,0])
evaluatePosition2(state, bigState, pos, 0) #1-1block corner corner
print('1-1block corner corner\n')
state = array('b', [1,0,0,0,2,0,0,0,0])
evaluatePosition2(state, bigState, pos, 0) #1-1block centre corner
print('1-1block centre corner\n')
state = array('b', [0,2,0,0,1,0,0,0,0])
evaluatePosition2(state, bigState, pos, 0) #1-1block centre side
print('1-1block centre side\n\n')

state = array('b', [1,0,0,0,0,2,0,0,0])
evaluatePosition2(state, bigState, pos, 0) #1-1 no block
print('1-1 no block')

#state = array('b', [1,0,0,0,0,0,0,0,0])
#print('evaluatePosition2(state, bigState, pos, 0)')

def loop(states, tree):
    r = int(len(states)*random.random()/81)
    a = states[81*r:81*r+81]
    a1, a2 = generateStates(a, tree[6*r+4], tree[6*r+5], 6*r, len(states))
    states += a1
    tree += a2

#backProp(tree, int(2*random.random())+1, int(84*random.random())*6)
#tree, states = destroy(a, 10, 30, 2)
#timeit.timeit('d = destroy(a, 10000, 30, 2)', setup = 'from tictactoe_destroyer import destroy; from __main__ import a', number = 1)

#BOARD OF CONVENIENCE
"""
----------------------------------
| 00 01 02 | 09 10 11 | 18 19 20 |
| 03 04 05 | 12 13 14 | 21 22 23 |
| 06 07 08 | 15 16 17 | 24 25 26 |
------------------------
| 27 28 29 | 36 37 38 | 45 46 47 |
| 30 31 32 | 39 40 41 | 48 49 50 |
| 33 34 35 | 42 43 44 | 51 52 53 |
------------------------
| 54 55 56 | 63 64 65 | 72 73 74 |
| 57 58 59 | 66 67 68 | 75 76 77 |
| 60 61 62 | 69 70 71 | 78 79 80 |
----------------------------------
"""

#MAIN PROGRAM WHEN BATTLING
"""
a = array('b', [0 for i in range(81)])
turns = []

#turns = [40, 36, 2, 20, 24, 56, 26, 72, 8, 80, 76, 42, 57, 27, 5, 53, 78, 60, 59, 51, 58, 39, 29, 25, 65, 19, 11, 23, 52, 71, 74, 21, 35]
#write 69 after to replicate problem

for i in range(len(turns)):
    if i%2 == 0:
        a[turns[i]] = 1
    else:
        a[turns[i]] = 2

while True:
    enemy = int(input("Their turn: "))
    a[enemy] = 1
    turns.append(enemy)
    
    choices = [0 for i in range(81)]
    for i in range(3):
        ucbind, ucb = destroy(a,100,enemy,2)
        for j in range(len(ucbind)):
                choices[j] += ucb[j]

    del choices[len(ucbind):]
    ucbindL = list(ucbind)
    
    ucbindL = [x for _,x in sorted(zip(choices, ucbindL))]
    choices.sort()
    for i in range(len(choices)):
        print('%s: %s' %(ucbindL[i], choices[i]))
    
    me = ucbindL[-1]
    print("I think: %s" %me)
    a[me] = 2
    turns.append(me)
    
    #plt.bar([i for i in range(len(bars))], bars)
    #plt.savefig('poop.png')
    #plt.clf()
    
#"""
