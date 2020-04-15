#cython: language_level=3, cdivision=True

from cpython.array cimport array, clone, extend, resize #cython: language_level=3, boundscheck=False, wraparound=False, initializedcheck=False, cdivision=True
from libc.math cimport log
from concurrent.futures import ThreadPoolExecutor
import datetime

import random
sysRandom = random.SystemRandom()

from libc.stdlib cimport rand, srand, RAND_MAX
srand(<int>(1000*sysRandom.random()))

#+------------------------------------------------------------------------------+
#|                                                                   RollOut AI |
#+------------------------------------------------------------------------------+
cdef char findWin(array state, int i) nogil:
    cdef int j
    
    if state.data.as_chars[i+4] != 0:
        if (-1 != state.data.as_chars[i] == state.data.as_chars[i+4] == state.data.as_chars[i+8] or
            -1 != state.data.as_chars[i+2] == state.data.as_chars[i+4] == state.data.as_chars[i+6] or 
            -1 != state.data.as_chars[i+1] == state.data.as_chars[i+4] == state.data.as_chars[i+7] or 
            -1 != state.data.as_chars[i+3] == state.data.as_chars[i+4] == state.data.as_chars[i+5]):
            return(state.data.as_chars[i+4])
        
    if state.data.as_chars[i] != 0:
        if (-1 != state.data.as_chars[i] == state.data.as_chars[i+1] == state.data.as_chars[i+2] or 
            -1 != state.data.as_chars[i] == state.data.as_chars[i+3] == state.data.as_chars[i+6]):
            return(state.data.as_chars[i])
        
    if state.data.as_chars[i+8] != 0:
        if (-1 != state.data.as_chars[i+2] == state.data.as_chars[i+5] == state.data.as_chars[i+8] or 
            -1 != state.data.as_chars[i+6] == state.data.as_chars[i+7] == state.data.as_chars[i+8]):
            return(state.data.as_chars[i+8])
    
    for j in range(i, i+9):                 #filled but no winner
        if state.data.as_chars[j] == 0:
            break
    else:
        return(-1)
    
    return(0)
    
cdef checkNextDepth(array state, array bigState):
    return
    
#THERE WILL BE A NEXT CHOICE. NO CHOICE WILL BE CAUGHT IN ROLLOUT
cdef int randomState(array state, array bigState, array choices, int lastChoice) nogil:
    cdef int i, j=0, k, boxNo = lastChoice%9, nextChoice
    
    if bigState.data.as_chars[boxNo] == 0:  #ensure big box is not taken
        boxNo *= 9
        for i in range(boxNo, boxNo + 9):   #choices within the allocated box
            if state.data.as_chars[i] == 0:
                choices.data.as_ints[j] = i
                j += 1
    
    if j==0:                                #choices anywhere if allocated box is full or is won
        for i in range(9):
            if bigState.data.as_chars[i] == 0:  #account if big box is taken
                for k in range(i*9, i*9+9):
                    if state.data.as_chars[k] == 0:
                        choices.data.as_ints[j] = k
                        j += 1
    
    nextChoice = choices.data.as_ints[ <int> (j*rand()/<float>(RAND_MAX+1)) ]
    return(nextChoice)
    
cdef void evaluateSquare(array state, array bigState, array box, int ind, int player) nogil:
    cdef int i
    
    if bigState.data.as_chars[ind/9] != 0:  #if box is solved/full, 0 probability of choosing all squares box
        for i in range(ind, ind+9):
            box.data.as_floats[i] = 0
            box.data.as_floats[i+81] = 0
        return
        
    cdef float oneAdj=10, twoAdj=50, centre=5, corner=4, edge=3, block = 3
    cdef float b0=0, b1=0, b2=0, b3=0, b4=0, b5=0, b6=0, b7=0, b8=0, b9=0, b10=0, b11=0, b12=0, b13=0, b14=0, b15=0, b16=0, b17=0
    cdef char c0, c1, c2, c3, c4, c5, c6, c7, c8
    cdef int inter1, inter2
    
    c0 = state.data.as_chars[ind]
    c1 = state.data.as_chars[ind+1]
    c2 = state.data.as_chars[ind+2]
    c3 = state.data.as_chars[ind+3]
    c4 = state.data.as_chars[ind+4]
    c5 = state.data.as_chars[ind+5]
    c6 = state.data.as_chars[ind+6]
    c7 = state.data.as_chars[ind+7]
    c8 = state.data.as_chars[ind+8]
    
    if c0 == 0:
        #at least two completable adjacent: 011, 022
        if ((c1 == c2 == 1) + (c3 == c6 == 1) + (c4 == c8 == 1)) != 0:
            b0 += twoAdj
            b9 += oneAdj
        else:
            b0 += corner
            #at least one completable adjacent: 010, 001, 020, 002, 011, 022
            inter1 = ( (c1 + c2) == 1) + ( (c3 + c6) == 1) + ( (c4 + c8) == 1)
            b0 += oneAdj*inter1
            b9 += block*inter1
        
        if ((c1 == c2 == 2) + (c3 == c6 == 2) + (c4 == c8 == 2)) != 0:
            b9 += twoAdj
            b0 += oneAdj
        else:
            b9 += corner
            inter2 = ((c1 + c2) == 2 and c1 != c2) + ((c3 + c6) == 2 and c3 != c6) + ((c4 + c8) == 2 and c4 != c8)
            b9 += oneAdj*inter2
            b0 += block*inter2
    box.data.as_floats[ind] = b0
    box.data.as_floats[ind + 81] = b9

    if c1 == 0:
        if ((c0 == c2 == 1) + (c4 == c7 == 1)) != 0:
            b1 += twoAdj
            b10 += oneAdj
        else:
            b1 += edge
            inter1 = ( (c0 + c2) == 1) + ( (c4 + c7) == 1)
            b1 += oneAdj*inter1
            b10 += block*inter1
        
        if ((c0 == c2 == 2) + (c4 == c7 == 2)) != 0:
            b10 += twoAdj
            b1 += oneAdj
        else:
            b10 += edge
            inter2 = ((c0 + c2) == 2 and c0 != c2) + ((c4 + c7) == 2 and c4 != c7)
            b10 += oneAdj*inter2
            b1 += block*inter2
    box.data.as_floats[ind + 1] = b1
    box.data.as_floats[ind + 82] = b10
    
    if c2 == 0:
        if ((c0 == c1 == 1) + (c4 == c6 == 1) + (c5 == c8 == 1)) != 0:
            b2 += twoAdj
            b11 += oneAdj
        else:
            b2 += corner
            inter1 = ( (c0 + c1) == 1) + ( (c4 + c6) == 1) + ( (c5 + c8) == 1)
            b2 += oneAdj*inter1
            b11 += block*inter1
        
        if ((c0 == c1 == 2) + (c4 == c6 == 2) + (c5 == c8 == 2)) != 0:
            b11 += twoAdj
            b2 += oneAdj
        else:
            b11 += corner
            inter2 = ((c0 + c1) == 2 and c0 != c1) + ((c4 + c6) == 2 and c4 != c6) + ((c5 + c8) == 2 and c5 != c8)
            b11 += oneAdj*inter2
            b2 += block*inter2
    box.data.as_floats[ind + 2] = b2
    box.data.as_floats[ind + 83] = b11
    
    if c3 == 0:
        if ((c0 == c6 == 1) + (c4 == c5 == 1)) != 0:
            b3 += twoAdj
            b12 += oneAdj
        else:
            b3 += edge
            inter1 = ( (c0 + c6) == 1) + ( (c4 + c5) == 1)
            b3 += oneAdj*inter1
            b12 += block*inter1
        
        if ((c0 == c6 == 2) + (c4 == c5 == 2)) != 0:
            b12 += twoAdj
            b3 += oneAdj
        else:
            b12 += edge
            inter2 = ((c0 + c6) == 2 and c0 != c6) + ((c4 + c5) == 2 and c4 != c5)
            b12 += oneAdj*inter2
            b3 += block*inter2
    box.data.as_floats[ind + 3] = b3
    box.data.as_floats[ind + 84] = b12
    
    if c4 == 0:
        if ((c0 == c8 == 1) + (c2 == c6 == 1) + (c1 == c7 == 1) + (c3 == c5 == 1)) != 0:
            b4 += twoAdj
            b13 += oneAdj
        else:
            b4 += centre
            inter1 = ( (c0 + c8) == 1) + ( (c2 + c6) == 1) + ( (c1 + c7) == 1) + ( (c3 + c5) == 1)
            b4 += oneAdj*inter1
            b13 += block*inter1
        
        if ((c0 == c8 == 2) + (c2 == c6 == 2) + (c1 == c7 == 2) + (c3 == c5 == 2)) != 0:
            b13 += twoAdj
            b4 += oneAdj
        else:
            b13 += centre
            inter2 = ((c0 + c8) == 2 and c0 != c8) + ((c2 + c6) == 2 and c2 != c6) + ((c1 + c7) == 2 and c1 != c7) + ((c3 + c5) == 2 and c3 != c5)
            b13 += oneAdj*inter2
            b4 += block*inter2
    box.data.as_floats[ind + 4] = b4
    box.data.as_floats[ind + 85] = b13
    
    if c5 == 0:
        if ((c3 == c4 == 1) + (c2 == c8 == 1)) != 0:
            b5 += twoAdj
            b14 += oneAdj
        else:
            b5 += edge
            inter1 = ( (c3 + c4) == 1) + ( (c2 + c8) == 1)
            b5 += oneAdj*inter1
            b14 += block*inter1
        
        if ((c3 == c4 == 2) + (c2 == c8 == 2)) != 0:
            b14 += twoAdj
            b5 += oneAdj
        else:
            b14 += edge
            inter2 = ((c3 + c4) == 2 and c3 != c4) + ((c2 + c8) == 2 and c2 != c8)
            b14 += oneAdj*inter2
            b5 += block*inter2
    box.data.as_floats[ind + 5] = b5
    box.data.as_floats[ind + 86] = b14
    
    if c6 == 0:
        if ((c0 == c3 == 1) + (c2 == c4 == 1) + (c7 == c8 == 1)) != 0:
            b6 += twoAdj
            b15 += oneAdj
        else:
            b6 += corner
            inter1 = ( (c0 + c3) == 1) + ( (c2 + c4) == 1) + ( (c7 + c8) == 1)
            b6 += oneAdj*inter1
            b15 += block*inter1
        
        if ((c0 == c3 == 2) + (c2 == c4 == 2) + (c7 == c8 == 2)) != 0:
            b15 += twoAdj
            b6 += oneAdj
        else:
            b15 += corner
            inter2 = ((c0 + c3) == 2 and c0 != c3) + ((c2 + c4) == 2 and c2 != c4) + ((c7 + c8) == 2 and c7 != c8)
            b15 += oneAdj*inter2
            b6 += block*inter2
    box.data.as_floats[ind + 6] = b6
    box.data.as_floats[ind + 87] = b15
    
    if c7 == 0:
        if ((c1 == c4 == 1) + (c6 == c8 == 1)) != 0:
            b7 += twoAdj
            b16 += oneAdj
        else:
            b7 += edge
            inter1 = ( (c1 + c4) == 1) + ( (c6 + c8) == 1)
            b7 += oneAdj*inter1
            b16 += block*inter1
        
        if ((c1 == c4 == 2) + (c6 == c8 == 2)) != 0:
            b16 += twoAdj
            b7 += oneAdj
        else:
            b16 += edge
            inter2 = ((c1 + c4) == 2 and c1 != c4) + ((c6 + c8) == 2 and c6 != c8)
            b16 += oneAdj*inter2
            b7 += block*inter2
    box.data.as_floats[ind + 7] = b7
    box.data.as_floats[ind + 88] = b16
    
    if c8 == 0:
        if ((c0 == c4 == 1) + (c2 == c5 == 1) + (c6 == c7 == 1)) != 0:
            b8 += twoAdj
            b17 += oneAdj
        else:
            b8 += corner
            inter1 = ( (c0 + c4) == 1) + ( (c2 + c5) == 1) + ( (c6 + c7) == 1)
            b8 += oneAdj*inter1
            b17 += block*inter1
        
        if ((c0 == c4 == 2) + (c2 == c5 == 2) + (c6 == c7 == 2)) != 0:
            b17 += twoAdj
            b8 += oneAdj
        else:
            b17 += corner
            inter2 = ((c0 + c4) == 2 and c0 != c4) + ((c2 + c5) == 2 and c2 != c5) + ((c6 + c7) == 2 and c6 != c7)
            b17 += oneAdj*inter2
            b8 += block*inter2
    box.data.as_floats[ind + 8] = b8
    box.data.as_floats[ind + 89] = b17
    
cdef void evaluatePosition(array state, array bigState, array pos, int ind) nogil:
    if bigState.data.as_chars[ind/9] != 0:  #if big box solved/full, positional advantage eats shit
        pos.data.as_floats[ind/9] = -1000000
        pos.data.as_floats[9 + ind/9] = -1000000
        return
        
    cdef float oneAdj=5, twoAdj=50
    cdef float s1 = 0, s2 = 0
    cdef int inter1 = 0, inter2 = 0
    cdef char c0, c1, c2, c3, c4, c5, c6, c7, c8
    
    c0 = state.data.as_chars[ind]
    c1 = state.data.as_chars[ind+1]
    c2 = state.data.as_chars[ind+2]
    c3 = state.data.as_chars[ind+3]
    c4 = state.data.as_chars[ind+4]
    c5 = state.data.as_chars[ind+5]
    c6 = state.data.as_chars[ind+6]
    c7 = state.data.as_chars[ind+7]
    c8 = state.data.as_chars[ind+8]
    
    if c0 == 0:
        inter1 += (c1 == c2 == 1) + (c3 == c6 == 1) + (c4 == c8 == 1)
        inter2 += (c1 == c2 == 2) + (c3 == c6 == 2) + (c4 == c8 == 2)
    if c1 == 0:
        inter1 += (c0 == c2 == 1) + (c4 == c7 == 1)
        inter2 += (c0 == c2 == 2) + (c4 == c7 == 2)
    if c2 == 0:
        inter1 += (c0 == c1 == 1) + (c4 == c6 == 1) + (c5 == c8 == 1)
        inter2 += (c0 == c1 == 2) + (c4 == c6 == 2) + (c5 == c8 == 2)
    if c3 == 0:
        inter1 += (c0 == c6 == 1) + (c4 == c5 == 1)
        inter2 += (c0 == c6 == 2) + (c4 == c5 == 2)
    if c4 == 0:
        inter1 += (c0 == c8 == 1) + (c2 == c6 == 1) + (c1 == c7 == 1) + (c3 == c5 == 1)
        inter2 += (c0 == c8 == 2) + (c2 == c6 == 2) + (c1 == c7 == 2) + (c3 == c5 == 2)
    if c5 == 0:
        inter1 += (c3 == c4 == 1) + (c2 == c8 == 1)
        inter2 += (c3 == c4 == 2) + (c2 == c8 == 2)
    if c6 == 0:
        inter1 += (c0 == c3 == 1) + (c2 == c4 == 1) + (c7 == c8 == 1)
        inter2 += (c0 == c3 == 2) + (c2 == c4 == 2) + (c7 == c8 == 2)
    if c7 == 0:
        inter1 += (c1 == c4 == 1) + (c6 == c8 == 1)
        inter2 += (c1 == c4 == 2) + (c6 == c8 == 2)
    if c8 == 0:
        inter1 += (c0 == c4 == 1) + (c2 == c5 == 1) + (c6 == c7 == 1)
        inter2 += (c0 == c4 == 2) + (c2 == c5 == 2) + (c6 == c7 == 2)
    
    if inter1 > 0:
        s1 = twoAdj
    else:
        if c0 == 0:
            s1 += ((c1 + c2) == 1) + ((c3 + c6) == 1) + ((c4 + c8) == 1) #01, 10
        if c1 == 0:
            s1 += ((c0 + c2) == 1) + ((c4 + c7) == 1)
        if c2 == 0:
            s1 += ((c0 + c1) == 1) + ((c4 + c6) == 1) + ((c5 + c8) == 1)
        if c3 == 0:
            s1 += ((c0 + c6) == 1) + ((c4 + c5) == 1)
        if c4 == 0:
            s1 += ((c0 + c8) == 1) + ((c2 + c6) == 1) + ((c1 + c7) == 1) + ((c3 + c5) == 1)
        if c5 == 0:
            s1 += ((c3 + c4) == 1) + ((c2 + c8) == 1)
        if c6 == 0:
            s1 += ((c0 + c3) == 1) + ((c2 + c4) == 1) + ((c7 + c8) == 1)
        if c7 == 0:
            s1 += ((c1 + c4) == 1) + ((c6 + c8) == 1)
        if c8 == 0:
            s1 += ((c0 + c4) == 1) + ((c2 + c5) == 1) + ((c6 + c7) == 1)
        s1 *= oneAdj
        
    if inter2 > 0:
        s2 = twoAdj
    else:
        if c0 == 0:
            s2 += ((c1 + c2) == 2 and c1 != c2) + ((c3 + c6) == 2 and c3 != c6) + ((c4 + c8) == 2 and c4 != c8) #02, 20
        if c1 == 0:
            s2 += ((c0 + c2) == 2 and c0 != c2) + ((c4 + c7) == 2 and c4 != c7)
        if c2 == 0:
            s2 += ((c0 + c1) == 2 and c0 != c1) + ((c4 + c6) == 2 and c4 != c6) + ((c5 + c8) == 2 and c5 != c8)
        if c3 == 0:
            s2 += ((c0 + c6) == 2 and c0 != c6) + ((c4 + c5) == 2 and c4 != c5)
        if c4 == 0:
            s2 += ((c0 + c8) == 2 and c0 != c8) + ((c2 + c6) == 2 and c2 != c6) + ((c1 + c7) == 2 and c1 != c7) + ((c3 + c5) == 2 and c3 != c5)
        if c5 == 0:
            s2 += ((c3 + c4) == 2 and c3 != c4) + ((c2 + c8) == 2 and c2 != c8)
        if c6 == 0:
            s2 += ((c0 + c3) == 2 and c0 != c3) + ((c2 + c4) == 2 and c2 != c4) + ((c7 + c8) == 2 and c7 != c8)
        if c7 == 0:
            s2 += ((c1 + c4) == 2 and c1 != c4) + ((c6 + c8) == 2 and c6 != c8)
        if c8 == 0:
            s2 += ((c0 + c4) == 2 and c0 != c4) + ((c2 + c5) == 2 and c2 != c5) + ((c6 + c7) == 2 and c6 != c7)
        s2 *= oneAdj
        
    pos.data.as_floats[ind/9] = s1
    pos.data.as_floats[9 + ind/9] = s2
 
#THERE WILL BE A NEXT CHOICE. NO CHOICE WILL BE CAUGHT IN ROLLOUT
cdef int basic(array scores, array pos, array choices, int lastChoice, int player) nogil:
    cdef int i, j, nextChoice = -1, boxind = lastChoice%9 * 9
    cdef float currScore, randSum = 0, r = 0, m1 = 1.5*(player==1)-1, m2 = 1.5*(player==2)-1
    
    for i in range(9):                                          #no need to check box, if box is won/full, score will be 0
        if scores.data.as_floats[boxind + i] == 0:              #ensure no won/full box OR filled square
            choices.data.as_floats[i] = 0
            continue
        
        #pos < 9 for player 1, > 0 for player 2
        currScore = scores.data.as_floats[boxind + i] + m1*pos.data.as_floats[i] + m2*pos.data.as_floats[i+9]
        if pos.data.as_floats[i] == -1000000 or currScore <= 0: #check if next box is won/full: destroy the probability
            currScore = 1                                       #shit probability if |pos| > score, CANNOT BE 0
        currScore *= currScore
        
        choices.data.as_floats[i] = currScore
        r += currScore
        
    if r == 0:                                                  #box is full/won
        for i from 0 <= i < 81 by 9:                            #choose across the board
            for j in range(9):
                if scores.data.as_floats[i + j] == 0:           #ensure no won/full box OR filled square
                    choices.data.as_floats[i + j] = 0
                    continue
                
                currScore = scores.data.as_floats[i + j] + m1*pos.data.as_floats[j] + m2*pos.data.as_floats[j+9]
                if pos.data.as_floats[j] == -1000000 or currScore <= 0:                     #check if next box is won/full: destroy the probability
                    currScore = 1
                currScore *= currScore
                
                choices.data.as_floats[i + j] = currScore
                r += currScore
        boxind = 0
    
    r *= rand()/<float>(RAND_MAX+1)                             #random among the scores
    i = 0
    while nextChoice == -1:
        randSum += choices.data.as_floats[i]
        if randSum >= r:
            nextChoice = i + boxind
            break
        i += 1
    
    return(nextChoice)

#+------------------------------------------------------------------------------+
#|                                                               MCTS Functions |
#+------------------------------------------------------------------------------+
cdef array generateStates(array state, array tree, int treeLen, int lastChoice, char nextPlayer, int parent, int stateLen):   #0 means nothing placed
    cdef int i, j = treeLen, k, boxNo = lastChoice%9, otherPlayer
    cdef array newStates = array('b'), bigState
    resize(tree, treeLen + 456)
    
    bigState = clone(array('b'), 9, False)              #determine state of game
    for i from 0 <= i < 81 by 9:
        bigState.data.as_chars[i/9] = findWin(state, i)
    
    if nextPlayer == 1:
        otherPlayer = 2
    else:
        otherPlayer = 1
    
    if bigState.data.as_chars[boxNo] == 0:              #ensure big box is not taken
        boxNo *= 9
        for i in range(boxNo, boxNo + 9):
            if state.data.as_chars[i] == 0:
                state.data.as_chars[i] = nextPlayer
                extend(newStates, state)
                state.data.as_chars[i] = 0
                
                tree.data.as_ints[j] = parent               #parent index
                tree.data.as_ints[j+1] = 0                  #wins
                tree.data.as_ints[j+2] = 0                  #runs
                tree.data.as_ints[j+3] = stateLen + 81*(j-treeLen)/6  #corresponding state index
                tree.data.as_ints[j+4] = i
                tree.data.as_ints[j+5] = otherPlayer
                j += 6
                
    if j == treeLen:    #choices anywhere if allocated box is won or full
        #print('treelen %s, lastchoice %s, nextPlayer %s, parent %s, stateLen %s' %(treeLen, lastChoice, nextPlayer, parent, stateLen))
        for i in range(9):
            if bigState.data.as_chars[i] == 0:
                for k in range(i*9, i*9 + 9):
                    if state.data.as_chars[k] == 0:
                        state.data.as_chars[k] = nextPlayer
                        extend(newStates, state)
                        state.data.as_chars[k] = 0
                        
                        tree.data.as_ints[j] = parent               #parent index
                        tree.data.as_ints[j+1] = 0                  #wins
                        tree.data.as_ints[j+2] = 0                  #runs
                        tree.data.as_ints[j+3] = stateLen + 81*(j-treeLen)/6  #corresponding state index
                        tree.data.as_ints[j+4] = k
                        tree.data.as_ints[j+5] = otherPlayer
                        j += 6
                        
    resize(tree, j)
    return(newStates)

cdef int calculateUCB(array tree, int parentInd, float c):   #returns tree index corresponding to parent
    #tree = [ [parent, wins, runs, stateind, lastChoice, nextPlayer] ... ]
    cdef int i, treeLen = len(tree), parentRuns = tree.data.as_ints[parentInd + 2], maxInd = -1
    cdef float ucb, maxUCB = -1000
    
    for i from parentInd <= i < treeLen by 6:
        if tree.data.as_ints[i] == parentInd:
            
            if tree.data.as_ints[i+2] == 0:     #indicates infinite UCB
                return(-i)
            #nodeWins / nodeRuns + c * sqrt(ln(parentRuns) / nodeRuns)
            ucb = <float>tree.data.as_ints[i+1]/tree.data.as_ints[i+2] + c * ( log(parentRuns)/tree.data.as_ints[i+2])**0.5
            
            if ucb > maxUCB:
                maxUCB = ucb
                maxInd = i
            
            if i+6 != treeLen and tree.data.as_ints[i+6] != parentInd:
                break
    
    return(maxInd)

def showUCB(array tree, float c):
    cdef int i, j = 0, treeLen = len(tree), parentRuns = tree.data.as_ints[2]
    cdef array ucb, ucbind
    ucb = clone(array('f'), 81, False)
    ucbind = clone(array('i'), 81, False)
    
    for i from 0 <= i < treeLen by 6:
        if tree.data.as_ints[i] == 0:
            ucb.data.as_floats[j] = <float>tree.data.as_ints[i+1]/tree.data.as_ints[i+2] + c * ( log(parentRuns)/tree.data.as_ints[i+2])**0.5
            ucbind.data.as_ints[j] = tree.data.as_ints[i+4]
            j += 1
            
            if tree.data.as_ints[i+6] != 0:
                break
    
    resize(ucb, j)
    resize(ucbind, j)
    ucbL = list(ucb)
    ucbindL = list(ucbind)
    
    ucbindL = [x for _,x in sorted(zip(ucbL, ucbindL))]
    ucbL.sort()
    
    #for i in range(j):
        #print('%s: %s' %(ucbindL[i], ucbL[i]))
    
    return(ucbind, ucb)

cdef int rollOut(array leafState, int leafChoice, char leafPlayer, int runs):  #state has to be 81 long
    cdef array state, bigState, choices#, scores, bigScores
    cdef int run, wins = 0, i, j, lastChoice
    cdef char winner, nextPlayer
    
    state = clone(array('b'), 81, False)
    bigState = clone(array('b'), 9, False)
    #scores = clone(array('f'), 81, False)
    #bigScores = clone(array('f'), 18, False)
    choices = clone(array('f'), 81, False)
    
    with nogil:
        for run in range(runs):
            
            for i in range(9):                                  #reset the following:
                for j in range(i*9, i*9 + 9):                   #state: check if box is 0
                    state.data.as_chars[j] = leafState.data.as_chars[j]
                bigState.data.as_chars[i] = findWin(state, i*9) #big state: check end game condition
                #evaluatePosition(state, bigState, bigScores, i*9)   #bigScores: check positional advantages
                #evaluateSquare(state, bigState, scores, 9*i)        #scores: boardwide scores
            lastChoice = leafChoice
            nextPlayer = leafPlayer
            winner = 0
            
            while True:
                
                #lastChoice = basic(scores, bigScores, choices, lastChoice, nextPlayer) #select highest scoring depending on box filled
                lastChoice = randomState(state, bigState, choices, lastChoice)
                
                j = lastChoice/9 * 9
                state.data.as_chars[lastChoice] = nextPlayer            #update states
                bigState.data.as_chars[lastChoice/9] = findWin(state, j)
                winner = findWin(bigState, 0)
                
                if winner != 0:
                    """
                    if winner == -1:    #DRAW
                        #print("DRAW, %s, %s" %(bigState, bigScores))
                        for i in range(9):
                            for j in range(i*9, i*9 + 9):                   #state: check if box is 0
                                state.data.as_chars[j] = leafState.data.as_chars[j]
                            bigState.data.as_chars[i] = findWin(state, i*9) #big state: check end game condition
                            evaluatePosition(state, bigState, bigScores, i*9)         #bigScores: check positional advantages
                            evaluateSquare(state, bigState, scores, 9*i)          #scores: boardwide scores
                        lastChoice = leafChoice
                        nextPlayer = leafPlayer
                        winner = 0
                        continue
                    else:
                        break
                    """
                    break
                    
                #evaluatePosition(state, bigState, bigScores, j)  #filled box scores = 0, else calculate
                #evaluateSquare(state, bigState, scores, j)   #filled box score = -1000000, else calculate
                """
                with gil:
                    showState(state)
                    print('%s: %s' %(lastChoice, choices[:9]))
                    print('%s: %s, win: %s, j:%s' %(nextPlayer, lastChoice, winner, j))
                    print(state[j:j+9])
                    print(bigState)
                    print('scores: %s' %scores[j:j+9])
                    print('s1: %s' %bigScores[:9])
                    print('s2: %s' %bigScores[-9:])
                #"""
                if nextPlayer == 1:
                    nextPlayer = 2
                else:
                    nextPlayer = 1
            
            #print('winner %s/%s, %s' %(winner, leafPlayer, bigState))
            
            if winner == -1:
                wins += 1
            elif winner != leafPlayer:
                wins += 2
            
    #print('TOTAL SCORE: winner %s/%s, wins %s/%s' %(winner, leafPlayer, wins, runs))
    return(wins)
    
cdef void backProp(array tree, char winner, int leafInd, int wins, int runs):
    cdef int i, parent = leafInd, treeLen = len(tree)   #start from current leaf
    
    while parent != -1:                             #-1 is root's parent
        if tree.data.as_ints[parent + 5] == winner:
            tree.data.as_ints[parent + 1] += wins   #wins
        else:
            tree.data.as_ints[parent + 1] += runs-wins   
        tree.data.as_ints[parent + 2] += runs       #runs
        
        parent = tree.data.as_ints[parent]

#+------------------------------------------------------------------------------+
#|                                                                    MCTS Main |
#+------------------------------------------------------------------------------+
def destroy(array state, int runs, int rootLastChoice, char rootNextPlayer):    #0 means nothing placed
    """
    1) consider value of 1/2 COMPLETABLE adjacents from both sides
    2) consider value of centre/corner/edge
    3) consider value of next box from both sides NOT DONE
    4) full/won destroys probability of choosing
    
    RANDOM STATE:
    - 1 deep search to avoid loss
    - 2 deep search to avoid loss
    
    BASIC: (stupider cause scores are based on 1-deep search)
    !- add score constant so positional advantages will not result in negative score, accounted for when randomizing
    !- Positional advantages VS small square advantages
    !- know WHEN to win the square
    !- account if square is important to win
    
    - wrong idea of pos: when advantageous doesnt mean put at that square, when disadvantageous does not mean avoid it.
    """
    
    cdef int i, j, k, leafInd, rollOutStatesInd, lastChoice, statesNo = 1, wins
    cdef char nextPlayer
    cdef array tree, states, newStates, newNodes, currState
    
    tree = clone(array('i'), 6, zero = True)        #[ [parent, wins, runs, stateind, lastChoice, nextPlayer] ... ]
    tree.data.as_ints[0] = -1                       #root parent must be invalid
    tree.data.as_ints[4] = rootLastChoice
    tree.data.as_ints[5] = rootNextPlayer
    
    states = clone(array('b'), 81, zero = True)     #[ [81 boxes] ... ]
    currState = clone(array('b'), 81, False)
    for i in range(81):
        states.data.as_chars[i] = state.data.as_chars[i]
    
    for i in range(runs):
        
        #print('\n%s' %datetime.datetime.now().time())
        
        leafInd = 0                              #find most promising leaf, starting from root
        while True:
            j = calculateUCB(tree, leafInd, 2)   #exploration parameter, c = 2, returns most winnable node index, corresponding to parent
            if j == -1:                             #leaf is reached and visited, leafInd = previous
                break
            leafInd = j
            if j < 0:                               #leaf is not visited, leafInd = current but negative
                break
        
        if leafInd < 0:                             #leaf runs = 0, rollout
            leafInd = -leafInd
            #print('%s Not visited, doing a play out on %s' %(datetime.datetime.now().time(), leafInd))
        
        rollOutStatesInd = tree.data.as_ints[leafInd + 3]
        lastChoice = tree.data.as_ints[leafInd + 4]
        nextPlayer = tree.data.as_ints[leafInd + 5]
        for k in range(81):
            currState.data.as_chars[k] = states.data.as_chars[rollOutStatesInd + k]
        
        if j == -1:                                 #leaf runs != 0, expand and choose a random leaf
            newStates = generateStates(currState, tree, statesNo*6, lastChoice, nextPlayer, leafInd, statesNo*81)
            extend(states, newStates)
            statesNo += len(newStates)/81
            leafInd = 6 * (statesNo - <int>(len(newStates)/81 * rand()/<float>(RAND_MAX)) - 1)
            #print('%s Expanding on %s' %(datetime.datetime.now().time(), leafInd))
        
        #wins = rollOut(currState, lastChoice, nextPlayer, 1) #random plays till a side wins
        #print('%s Rollout done.' %datetime.datetime.now().time())
        #backProp(tree, lastChoice, leafInd, wins, 2)
        #"""
        with ThreadPoolExecutor(4) as exe:
            jobs = [exe.submit(rollOut, currState, lastChoice, nextPlayer, 2500) for i in range(4)]
        wins = 0
        for job in jobs:
            wins += job.result()
        #print('REAL TOTAL: %s/%s' %(wins,400))
        backProp(tree, lastChoice, leafInd, wins, 20000)
        #"""
        
        #k = leafInd
        #print('%s, parent %s, wins %s, runs %s, stateind %s, lastchoice %s, nextplayer %s' %(datetime.datetime.now().time(), tree[k], tree[k+1], tree[k+2], tree[k+3], tree[k+4], tree[k+5]) )
    
    print('This run thinks: %s' %tree.data.as_ints[calculateUCB(tree, 0, 2)+4])
    return(showUCB(tree, 2))
    #return(tree, states)
    
def showState(array state):
    cdef int i, j
    temp = ''
    print('------------------------')
    for i from 0 <= i < 81 by 27:
        for j from 0 <= j < 9 by 3:
            temp = ''
            for k from 0 <= k < 27 by 9:
                temp += '| %s:%s %s:%s %s:%s ' %(i+j+k+10, state.data.as_chars[i+j+k], i+j+k+11, state.data.as_chars[i+j+k+1], i+j+k+12, state.data.as_chars[i+j+k+2])
            temp += '|'
            print(temp)
        print('------------------------')

def evaluateSquare2(array state, array bigState, array box, int ind):
    cdef int i
    
    if bigState.data.as_chars[ind/9] != 0:  #if box is solved/full, 0 probability of choosing all squares box
        for i in range(ind, ind+9):
            box.data.as_floats[i] = 0
        return
        
    cdef float oneAdj=10, twoAdj=50, centre=5, corner=4, edge=3 #theoretically, block = adj1/4.5, adj1 = adj2/3.5, adj1 << adj2
    cdef float b0=0, b1=0, b2=0, b3=0, b4=0, b5=0, b6=0, b7=0, b8=0
    cdef char c0, c1, c2, c3, c4, c5, c6, c7, c8
    cdef int inter
    
    c0 = state.data.as_chars[ind]
    c1 = state.data.as_chars[ind+1]
    c2 = state.data.as_chars[ind+2]
    c3 = state.data.as_chars[ind+3]
    c4 = state.data.as_chars[ind+4]
    c5 = state.data.as_chars[ind+5]
    c6 = state.data.as_chars[ind+6]
    c7 = state.data.as_chars[ind+7]
    c8 = state.data.as_chars[ind+8]
    
    if c0 == 0:
        #at least two completable adjacent: 011, 022
        b0 = (c1 == c2 != 0) + (c3 == c6 != 0) + (c4 == c8 != 0)
        if b0 != 0:
            b0 = twoAdj
        else:
            b0 += corner
            #at least one completable adjacent: 010, 001, 020, 002, 011, 022
            b0 += oneAdj*( (0 != (c1 + c2) != 3) + (0 != (c3 + c6) != 3) + (0 != (c4 + c8) != 3))
    box.data.as_floats[ind] = b0

    if c1 == 0:
        b1 += (c0 == c2 != 0) + (c4 == c7 != 0)
        if b1 != 0:
            b1 = twoAdj
        else:
            b1 += edge
            b1 += oneAdj*( (0 != (c0 + c2) != 3) + (0 != (c4 + c7) != 3))
    box.data.as_floats[ind+1] = b1

    if c2 == 0:
        b2 += (c0 == c1 != 0) + (c4 == c6 != 0) + (c5 == c8 != 0)
        if b2 != 0:
            b2 = twoAdj
        else:
            b2 += corner
            b2 += oneAdj*( (0 != (c0 + c1) != 3) + (0 != (c4 + c6) != 3) + (0 != (c5 + c8) != 3))
    box.data.as_floats[ind+2] = b2

    if c3 == 0:
        b3 += (c0 == c6 != 0) + (c4 == c5 != 0)
        if b3 != 0:
            b3 = twoAdj
        else:
            b3 += edge
            b3 += oneAdj*( (0 != (c0 + c6) != 3) + (0 != (c4 + c5) != 3))
    box.data.as_floats[ind+3] = b3

    if c4 == 0:
        b4 += (c0 == c8 != 0) +(c2 == c6 != 0) +(c1 == c7 != 0) +(c3 == c5 != 0)
        if b4 != 0:
            b4 = twoAdj
        else:
            b4 += centre
            b4 += oneAdj*( (0 != (c0 + c8) != 3) + (0 != (c2 + c6) != 3) + (0 != (c1 + c7) != 3) + (0 != (c3 + c5) != 3))
    box.data.as_floats[ind+4] = b4

    if c5 == 0:
        b5 += (c3 == c4 != 0) + (c2 == c8 != 0)
        if b5 != 0:
            b5 = twoAdj
        else:
            b5 += edge
            b5 += oneAdj*( (0 != (c3 + c4) != 3) + (0 != (c2 + c8) != 3))
    box.data.as_floats[ind+5] = b5

    if c6 == 0:
        b6 += (c0 == c3 != 0) + (c2 == c4 != 0) + (c7 == c8 != 0)
        if b6 != 0:
            b6 = twoAdj
        else:
            b6 += corner
            b6 += oneAdj*( (0 != (c0 + c3) != 3) + (0 != (c2 + c4) != 3) + (0 != (c7 + c8) != 3))
    box.data.as_floats[ind+6] = b6

    if c7 == 0:
        b7 += (c1 == c4 != 0) + (c6 == c8 != 0)
        if b7 != 0:
            b7 = twoAdj
        else:
            b7 += edge
            b7 += oneAdj*( (0 != (c1 + c4) != 3) + (0 != (c6 + c8) != 3))
    box.data.as_floats[ind+7] = b7

    if c8 == 0:
        b8 += (c0 == c4 != 0) + (c2 == c5 != 0) + (c6 == c7 != 0)
        if b8 != 0:
            b8 = twoAdj
        else:
            b8 += corner
            b8 += oneAdj*( (0 != (c0 + c4) != 3) + (0 != (c2 + c5) != 3) + (0 != (c6 + c7) != 3))
    box.data.as_floats[ind+8] = b8
    
    print('box = %s' %box)
    print('state = %s' %state)

def evaluateSquare3(array state, array bigState, array box, int ind):
    cdef int i
    
    if bigState.data.as_chars[ind/9] != 0:  #if box is solved/full, 0 probability of choosing all squares box
        for i in range(ind, ind+9):
            box.data.as_floats[i] = 0
            box.data.as_floats[i+81] = 0
        return
        
    cdef float oneAdj=10, twoAdj=50, centre=5, corner=4, edge=3, block = 3
    cdef float b0=0, b1=0, b2=0, b3=0, b4=0, b5=0, b6=0, b7=0, b8=0, b9=0, b10=0, b11=0, b12=0, b13=0, b14=0, b15=0, b16=0, b17=0
    cdef char c0, c1, c2, c3, c4, c5, c6, c7, c8
    cdef int inter1, inter2
    
    c0 = state.data.as_chars[ind]
    c1 = state.data.as_chars[ind+1]
    c2 = state.data.as_chars[ind+2]
    c3 = state.data.as_chars[ind+3]
    c4 = state.data.as_chars[ind+4]
    c5 = state.data.as_chars[ind+5]
    c6 = state.data.as_chars[ind+6]
    c7 = state.data.as_chars[ind+7]
    c8 = state.data.as_chars[ind+8]
    
    if c0 == 0:
        #at least two completable adjacent: 011, 022
        if ((c1 == c2 == 1) + (c3 == c6 == 1) + (c4 == c8 == 1)) != 0:
            b0 += twoAdj
            b9 += oneAdj
        else:
            b0 += corner
            #at least one completable adjacent: 010, 001, 020, 002, 011, 022
            inter1 = ( (c1 + c2) == 1) + ( (c3 + c6) == 1) + ( (c4 + c8) == 1)
            b0 += oneAdj*inter1
            b9 += block*inter1
        
        if ((c1 == c2 == 2) + (c3 == c6 == 2) + (c4 == c8 == 2)) != 0:
            b9 += twoAdj
            b0 += oneAdj
        else:
            b9 += corner
            inter2 = ((c1 + c2) == 2 and c1 != c2) + ((c3 + c6) == 2 and c3 != c6) + ((c4 + c8) == 2 and c4 != c8)
            b9 += oneAdj*inter2
            b0 += block*inter2
    box.data.as_floats[ind] = b0
    box.data.as_floats[ind + 81] = b9

    if c1 == 0:
        if ((c0 == c2 == 1) + (c4 == c7 == 1)) != 0:
            b1 += twoAdj
            b10 += oneAdj
        else:
            b1 += edge
            inter1 = ( (c0 + c2) == 1) + ( (c4 + c7) == 1)
            b1 += oneAdj*inter1
            b10 += block*inter1
        
        if ((c0 == c2 == 2) + (c4 == c7 == 2)) != 0:
            b10 += twoAdj
            b1 += oneAdj
        else:
            b10 += edge
            inter2 = ((c0 + c2) == 2 and c0 != c2) + ((c4 + c7) == 2 and c4 != c7)
            b10 += oneAdj*inter2
            b1 += block*inter2
    box.data.as_floats[ind + 1] = b1
    box.data.as_floats[ind + 82] = b10
    
    if c2 == 0:
        if ((c0 == c1 == 1) + (c4 == c6 == 1) + (c5 == c8 == 1)) != 0:
            b2 += twoAdj
            b11 += oneAdj
        else:
            b2 += corner
            inter1 = ( (c0 + c1) == 1) + ( (c4 + c6) == 1) + ( (c5 + c8) == 1)
            b2 += oneAdj*inter1
            b11 += block*inter1
        
        if ((c0 == c1 == 2) + (c4 == c6 == 2) + (c5 == c8 == 2)) != 0:
            b11 += twoAdj
            b2 += oneAdj
        else:
            b11 += corner
            inter2 = ((c0 + c1) == 2 and c0 != c1) + ((c4 + c6) == 2 and c4 != c6) + ((c5 + c8) == 2 and c5 != c8)
            b11 += oneAdj*inter2
            b2 += block*inter2
    box.data.as_floats[ind + 2] = b2
    box.data.as_floats[ind + 83] = b11
    
    if c3 == 0:
        if ((c0 == c6 == 1) + (c4 == c5 == 1)) != 0:
            b3 += twoAdj
            b12 += oneAdj
        else:
            b3 += edge
            inter1 = ( (c0 + c6) == 1) + ( (c4 + c5) == 1)
            b3 += oneAdj*inter1
            b12 += block*inter1
        
        if ((c0 == c6 == 2) + (c4 == c5 == 2)) != 0:
            b12 += twoAdj
            b3 += oneAdj
        else:
            b12 += edge
            inter2 = ((c0 + c6) == 2 and c0 != c6) + ((c4 + c5) == 2 and c4 != c5)
            b12 += oneAdj*inter2
            b3 += block*inter2
    box.data.as_floats[ind + 3] = b3
    box.data.as_floats[ind + 84] = b12
    
    if c4 == 0:
        if ((c0 == c8 == 1) + (c2 == c6 == 1) + (c1 == c7 == 1) + (c3 == c5 == 1)) != 0:
            b4 += twoAdj
            b13 += oneAdj
        else:
            b4 += centre
            inter1 = ( (c0 + c8) == 1) + ( (c2 + c6) == 1) + ( (c1 + c7) == 1) + ( (c3 + c5) == 1)
            b4 += oneAdj*inter1
            b13 += block*inter1
        
        if ((c0 == c8 == 2) + (c2 == c6 == 2) + (c1 == c7 == 2) + (c3 == c5 == 2)) != 0:
            b13 += twoAdj
            b4 += oneAdj
        else:
            b13 += centre
            inter2 = ((c0 + c8) == 2 and c0 != c8) + ((c2 + c6) == 2 and c2 != c6) + ((c1 + c7) == 2 and c1 != c7) + ((c3 + c5) == 2 and c3 != c5)
            b13 += oneAdj*inter2
            b4 += block*inter2
    box.data.as_floats[ind + 4] = b4
    box.data.as_floats[ind + 85] = b13
    
    if c5 == 0:
        if ((c3 == c4 == 1) + (c2 == c8 == 1)) != 0:
            b5 += twoAdj
            b14 += oneAdj
        else:
            b5 += edge
            inter1 = ( (c3 + c4) == 1) + ( (c2 + c8) == 1)
            b5 += oneAdj*inter1
            b14 += block*inter1
        
        if ((c3 == c4 == 2) + (c2 == c8 == 2)) != 0:
            b14 += twoAdj
            b5 += oneAdj
        else:
            b14 += edge
            inter2 = ((c3 + c4) == 2 and c3 != c4) + ((c2 + c8) == 2 and c2 != c8)
            b14 += oneAdj*inter2
            b5 += block*inter2
    box.data.as_floats[ind + 5] = b5
    box.data.as_floats[ind + 86] = b14
    
    if c6 == 0:
        if ((c0 == c3 == 1) + (c2 == c4 == 1) + (c7 == c8 == 1)) != 0:
            b6 += twoAdj
            b15 += oneAdj
        else:
            b6 += corner
            inter1 = ( (c0 + c3) == 1) + ( (c2 + c4) == 1) + ( (c7 + c8) == 1)
            b6 += oneAdj*inter1
            b15 += block*inter1
        
        if ((c0 == c3 == 2) + (c2 == c4 == 2) + (c7 == c8 == 2)) != 0:
            b15 += twoAdj
            b6 += oneAdj
        else:
            b15 += corner
            inter2 = ((c0 + c3) == 2 and c0 != c3) + ((c2 + c4) == 2 and c2 != c4) + ((c7 + c8) == 2 and c7 != c8)
            b15 += oneAdj*inter2
            b6 += block*inter2
    box.data.as_floats[ind + 6] = b6
    box.data.as_floats[ind + 87] = b15
    
    if c7 == 0:
        if ((c1 == c4 == 1) + (c6 == c8 == 1)) != 0:
            b7 += twoAdj
            b16 += oneAdj
        else:
            b7 += edge
            inter1 = ( (c1 + c4) == 1) + ( (c6 + c8) == 1)
            b7 += oneAdj*inter1
            b16 += block*inter1
        
        if ((c1 == c4 == 2) + (c6 == c8 == 2)) != 0:
            b16 += twoAdj
            b7 += oneAdj
        else:
            b16 += edge
            inter2 = ((c1 + c4) == 2 and c1 != c4) + ((c6 + c8) == 2 and c6 != c8)
            b16 += oneAdj*inter2
            b7 += block*inter2
    box.data.as_floats[ind + 7] = b7
    box.data.as_floats[ind + 88] = b16
    
    if c8 == 0:
        if ((c0 == c4 == 1) + (c2 == c5 == 1) + (c6 == c7 == 1)) != 0:
            b8 += twoAdj
            b17 += oneAdj
        else:
            b8 += corner
            inter1 = ( (c0 + c4) == 1) + ( (c2 + c5) == 1) + ( (c6 + c7) == 1)
            b8 += oneAdj*inter1
            b17 += block*inter1
        
        if ((c0 == c4 == 2) + (c2 == c5 == 2) + (c6 == c7 == 2)) != 0:
            b17 += twoAdj
            b8 += oneAdj
        else:
            b17 += corner
            inter2 = ((c0 + c4) == 2 and c0 != c4) + ((c2 + c5) == 2 and c2 != c5) + ((c6 + c7) == 2 and c6 != c7)
            b17 += oneAdj*inter2
            b8 += block*inter2
    box.data.as_floats[ind + 8] = b8
    box.data.as_floats[ind + 89] = b17
    
    print('box1: %s' %box[:9])
    print('box2: %s' %box[-9:])
    print('state = %s' %state)

def evaluatePosition2(array state, array bigState, array pos, int ind):
    if bigState.data.as_chars[ind/9] != 0:  #if big box solved/full, positional advantage eats shit
        pos.data.as_floats[ind/9] = -1000000
        pos.data.as_floats[9 + ind/9] = -1000000
        return
        
    cdef float oneAdj=10, twoAdj=50, block = 3
    cdef float b1=0, b2=0, mult
    cdef char c0, c1, c2, c3, c4, c5, c6, c7, c8
    cdef int inter1, inter2
    
    c0 = state.data.as_chars[ind]
    c1 = state.data.as_chars[ind+1]
    c2 = state.data.as_chars[ind+2]
    c3 = state.data.as_chars[ind+3]
    c4 = state.data.as_chars[ind+4]
    c5 = state.data.as_chars[ind+5]
    c6 = state.data.as_chars[ind+6]
    c7 = state.data.as_chars[ind+7]
    c8 = state.data.as_chars[ind+8]
    
    if c0 == 0:
        #at least two completable adjacent: 011, 022
        if ((c1 == c2 == 1) + (c3 == c6 == 1) + (c4 == c8 == 1)) != 0:
            b1 += twoAdj
            b2 += oneAdj
        else:
            #at least one completable adjacent: 010, 001, 020, 002, 011, 022
            inter1 = ( (c1 + c2) == 1) + ( (c3 + c6) == 1) + ( (c4 + c8) == 1)
            b1 += oneAdj*inter1
            b2 += block*inter1
            mult += 1
        
        if ((c1 == c2 == 2) + (c3 == c6 == 2) + (c4 == c8 == 2)) != 0:
            b2 += twoAdj
            b1 += oneAdj
        else:
            inter2 = ((c1 + c2) == 2 and c1 != c2) + ((c3 + c6) == 2 and c3 != c6) + ((c4 + c8) == 2 and c4 != c8)
            b2 += oneAdj*inter2
            b1 += block*inter2
            mult += 1
            
    if c1 == 0:
        if ((c0 == c2 == 1) + (c4 == c7 == 1)) != 0:
            b1 += twoAdj
            b2 += oneAdj
        else:
            inter1 = ( (c0 + c2) == 1) + ( (c4 + c7) == 1)
            b1 += oneAdj*inter1
            b2 += block*inter1
            mult += 1
            
        if ((c0 == c2 == 2) + (c4 == c7 == 2)) != 0:
            b2 += twoAdj
            b1 += oneAdj
        else:
            inter2 = ((c0 + c2) == 2 and c0 != c2) + ((c4 + c7) == 2 and c4 != c7)
            b2 += oneAdj*inter2
            b1 += block*inter2
            mult += 1
            
    if c2 == 0:
        if ((c0 == c1 == 1) + (c4 == c6 == 1) + (c5 == c8 == 1)) != 0:
            b1 += twoAdj
            b2 += oneAdj
        else:
            inter1 = ( (c0 + c1) == 1) + ( (c4 + c6) == 1) + ( (c5 + c8) == 1)
            b1 += oneAdj*inter1
            b2 += block*inter1
            mult += 1
            
        if ((c0 == c1 == 2) + (c4 == c6 == 2) + (c5 == c8 == 2)) != 0:
            b2 += twoAdj
            b1 += oneAdj
        else:
            inter2 = ((c0 + c1) == 2 and c0 != c1) + ((c4 + c6) == 2 and c4 != c6) + ((c5 + c8) == 2 and c5 != c8)
            b2 += oneAdj*inter2
            b1 += block*inter2
            mult += 1
            
    if c3 == 0:
        if ((c0 == c6 == 1) + (c4 == c5 == 1)) != 0:
            b1 += twoAdj
            b2 += oneAdj
        else:
            inter1 = ( (c0 + c6) == 1) + ( (c4 + c5) == 1)
            b1 += oneAdj*inter1
            b2 += block*inter1
            mult += 1
            
        if ((c0 == c6 == 2) + (c4 == c5 == 2)) != 0:
            b2 += twoAdj
            b1 += oneAdj
        else:
            inter2 = ((c0 + c6) == 2 and c0 != c6) + ((c4 + c5) == 2 and c4 != c5)
            b2 += oneAdj*inter2
            b1 += block*inter2
            mult += 1
            
    if c4 == 0:
        if ((c0 == c8 == 1) + (c2 == c6 == 1) + (c1 == c7 == 1) + (c3 == c5 == 1)) != 0:
            b1 += twoAdj
            b2 += oneAdj
        else:
            inter1 = ( (c0 + c8) == 1) + ( (c2 + c6) == 1) + ( (c1 + c7) == 1) + ( (c3 + c5) == 1)
            b1 += oneAdj*inter1
            b2 += block*inter1
            mult += 1
            
        if ((c0 == c8 == 2) + (c2 == c6 == 2) + (c1 == c7 == 2) + (c3 == c5 == 2)) != 0:
            b2 += twoAdj
            b1 += oneAdj
        else:
            inter2 = ((c0 + c8) == 2 and c0 != c8) + ((c2 + c6) == 2 and c2 != c6) + ((c1 + c7) == 2 and c1 != c7) + ((c3 + c5) == 2 and c3 != c5)
            b2 += oneAdj*inter2
            b1 += block*inter2
            mult += 1
            
    if c5 == 0:
        if ((c3 == c4 == 1) + (c2 == c8 == 1)) != 0:
            b1 += twoAdj
            b2 += oneAdj
        else:
            inter1 = ( (c3 + c4) == 1) + ( (c2 + c8) == 1)
            b1 += oneAdj*inter1
            b2 += block*inter1
            mult += 1
            
        if ((c3 == c4 == 2) + (c2 == c8 == 2)) != 0:
            b2 += twoAdj
            b1 += oneAdj
        else:
            inter2 = ((c3 + c4) == 2 and c3 != c4) + ((c2 + c8) == 2 and c2 != c8)
            b2 += oneAdj*inter2
            b1 += block*inter2
            mult += 1
            
    if c6 == 0:
        if ((c0 == c3 == 1) + (c2 == c4 == 1) + (c7 == c8 == 1)) != 0:
            b1 += twoAdj
            b2 += oneAdj
        else:
            inter1 = ( (c0 + c3) == 1) + ( (c2 + c4) == 1) + ( (c7 + c8) == 1)
            b1 += oneAdj*inter1
            b2 += block*inter1
            mult += 1
            
        if ((c0 == c3 == 2) + (c2 == c4 == 2) + (c7 == c8 == 2)) != 0:
            b2 += twoAdj
            b1 += oneAdj
        else:
            inter2 = ((c0 + c3) == 2 and c0 != c3) + ((c2 + c4) == 2 and c2 != c4) + ((c7 + c8) == 2 and c7 != c8)
            b2 += oneAdj*inter2
            b1 += block*inter2
            mult += 1
            
    if c7 == 0:
        if ((c1 == c4 == 1) + (c6 == c8 == 1)) != 0:
            b1 += twoAdj
            b2 += oneAdj
        else:
            inter1 = ( (c1 + c4) == 1) + ( (c6 + c8) == 1)
            b1 += oneAdj*inter1
            b2 += block*inter1
            mult += 1
            
        if ((c1 == c4 == 2) + (c6 == c8 == 2)) != 0:
            b2 += twoAdj
            b1 += oneAdj
        else:
            inter2 = ((c1 + c4) == 2 and c1 != c4) + ((c6 + c8) == 2 and c6 != c8)
            b2 += oneAdj*inter2
            b1 += block*inter2
            mult += 1
            
    if c8 == 0:
        if ((c0 == c4 == 1) + (c2 == c5 == 1) + (c6 == c7 == 1)) != 0:
            b1 += twoAdj
            b2 += oneAdj
        else:
            inter1 = ( (c0 + c4) == 1) + ( (c2 + c5) == 1) + ( (c6 + c7) == 1)
            b1 += oneAdj*inter1
            b2 += block*inter1
            mult += 1
            
        if ((c0 == c4 == 2) + (c2 == c5 == 2) + (c6 == c7 == 2)) != 0:
            b2 += twoAdj
            b1 += oneAdj
        else:
            inter2 = ((c0 + c4) == 2 and c0 != c4) + ((c2 + c5) == 2 and c2 != c5) + ((c6 + c7) == 2 and c6 != c7)
            b2 += oneAdj*inter2
            b1 += block*inter2
            mult += 1
            
    pos.data.as_floats[ind/9] = b1/mult
    pos.data.as_floats[9 + ind/9] = b2/mult
    
    #print('pos1: %s' %pos[:9])
    #print('pos2: %s' %pos[-9:])
    print('pos1: %s, pos2: %s' %(pos[0]-pos[9], pos[9]-pos[0]))
    print('state = %s' %state)