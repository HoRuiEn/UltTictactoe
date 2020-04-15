#cython: language_level=3, cdivision=True

from cpython.array cimport array, clone, extend, resize #cython: language_level=3, boundscheck=False, wraparound=False, initializedcheck=False, cdivision=True
from libc.math cimport log
from concurrent.futures import ThreadPoolExecutor

import random
sysRandom = random.SystemRandom()

from libc.stdlib cimport rand, srand, RAND_MAX
srand(<int>(1000*sysRandom.random()))

#+------------------------------------------------------------------------------+
#|                                                                   RollOut AI |
#+------------------------------------------------------------------------------+
cdef char findWin(array state, int i) nogil:    #0 means nothing placed
    
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
    
    return(0)
    
cdef int randomState(array state, array choices, int lastChoice, char nextPlayer, array bigState) nogil:
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
    
    if j==0:                                #no other choice available
        return(-1)
    
    nextChoice = choices.data.as_ints[ <int> (j*rand()/<float>(RAND_MAX+1)) ]
    state.data.as_chars[nextChoice] = nextPlayer
    return(nextChoice)
    
cdef void evaluateSquare(array state, array box, int ind) nogil:
    cdef float oneAdj=10, twoAdj=30, centre=5, corner=4, edge=3
    cdef float b0=0, b1=0, b2=0, b3=0, b4=0, b5=0, b6=0, b7=0, b8=0
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
        b0 += corner
        #at least one completable adjacent: 010, 001, 020, 002, 011, 022
        b0 += oneAdj*( (0 != (c1 + c2) != 3) + (0 != (c3 + c6) != 3) + (0 != (c4 + c8) != 3))
        #at least two completable adjacent: 011, 022
        b0 += twoAdj*( (c1 == c2 != 0) + (c3 == c6 != 0) + (c4 == c8 != 0))

    if c1 == 0:
        b1 += edge
        b1 += oneAdj*( (0 != (c0 + c2) != 3) + (0 != (c4 + c7) != 3))
        b1 += twoAdj*( (c0 == c2 != 0) + (c4 == c7 != 0))
            
    if c2 == 0:
        b2 += corner
        b2 += oneAdj*( (0 != (c0 + c1) != 3) + (0 != (c4 + c6) != 3) + (0 != (c5 + c8) != 3))
        b2 += twoAdj*( (c0 == c1 != 0) + (c4 == c6 != 0) + (c5 == c8 != 0))
            
    if c3 == 0:
        b3 += edge
        b3 += oneAdj*( (0 != (c0 + c6) != 3) + (0 != (c4 + c5) != 3))
        b3 += twoAdj*( (c0 == c6 != 0) + (c4 == c5 != 0))
            
    if c4 == 0:
        b4 += centre
        b4 += oneAdj*( (0 != (c0 + c8) != 3) + (0 != (c2 + c6) != 3) + (0 != (c1 + c7) != 3) + (0 != (c3 + c5) != 3))
        b4 += twoAdj*( (c0 == c8 != 0) +(c2 == c6 != 0) +(c1 == c7 != 0) +(c3 == c5 != 0))
            
    if c5 == 0:
        b5 += edge
        b5 += oneAdj*( (0 != (c3 + c4) != 3) + (0 != (c2 + c8) != 3))
        b5 += twoAdj*( (c3 == c4 != 0) + (c2 == c8 != 0))
            
    if c6 == 0:
        b6 += corner
        b6 += oneAdj*( (0 != (c0 + c3) != 3) + (0 != (c2 + c4) != 3) + (0 != (c7 + c8) != 3))
        b6 += twoAdj*( (c0 == c3 != 0) + (c2 == c4 != 0) + (c7 == c8 != 0))
            
    if c7 == 0:
        b7 += edge
        b7 += oneAdj*( (0 != (c1 + c4) != 3) + (0 != (c6 + c8) != 3))
        b7 += twoAdj*( (c1 == c4 != 0) + (c6 == c8 != 0))
            
    if c8 == 0:
        b8 += corner
        b8 += oneAdj*( (0 != (c0 + c4) != 3) + (0 != (c2 + c5) != 3) + (0 != (c6 + c7) != 3))
        b8 += twoAdj*( (c0 == c4 != 0) + (c2 == c5 != 0) + (c6 == c7 != 0))
    
    box.data.as_floats[0] += b0
    box.data.as_floats[1] += b1
    box.data.as_floats[2] += b2
    box.data.as_floats[3] += b3
    box.data.as_floats[4] += b4
    box.data.as_floats[5] += b5
    box.data.as_floats[6] += b6
    box.data.as_floats[7] += b7
    box.data.as_floats[8] += b8

cdef void evaluatePosition(array state, array pos, int ind) nogil:
    cdef float oneAdj=5, twoAdj=30#, centre=5, corner=4, edge=3
    cdef float score = 0
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
        #score += corner
        score += oneAdj*( ((c1 + c2) == 1) + ((c3 + c6) == 1) + ((c4 + c8) == 1)) #01, 10
        score -= oneAdj*( ((c1 + c2) == 2 and c1 != c2) + ((c3 + c6) == 2 and c3 != c6) + ((c4 + c8) == 2 and c4 != c8)) #02, 20
        score += twoAdj*( (c1 == c2 == 1) + (c3 == c6 == 1) + (c4 == c8 == 1)) #11
        score -= twoAdj*( (c1 == c2 == 2) + (c3 == c6 == 2) + (c4 == c8 == 2)) #22
        
    if c1 == 0:
        #score += edge
        score += oneAdj*( ((c0 + c2) == 1) + ((c4 + c7) == 1))
        score -= oneAdj*( ((c0 + c2) == 2 and c0 != c2) + ((c4 + c7) == 2 and c4 != c7))
        score += twoAdj*( (c0 == c2 == 1) + (c4 == c7 == 1))
        score -= twoAdj*( (c0 == c2 == 2) + (c4 == c7 == 2))
        
    if c2 == 0:
        #score += corner
        score += oneAdj*( ((c0 + c1) == 1) + ((c4 + c6) == 1) + ((c5 + c8) == 1))
        score -= oneAdj*( ((c0 + c1) == 2 and c0 != c1) + ((c4 + c6) == 2 and c4 != c6) + ((c5 + c8) == 2 and c5 != c8))
        score += twoAdj*( (c0 == c1 == 1) + (c4 == c6 == 1) + (c5 == c8 == 1))
        score -= twoAdj*( (c0 == c1 == 2) + (c4 == c6 == 2) + (c5 == c8 == 2))
        
    if c3 == 0:
        #score += edge
        score += oneAdj*( ((c0 + c6) == 1) + ((c4 + c5) == 1))
        score -= oneAdj*( ((c0 + c6) == 2 and c0 != c6) + ((c4 + c5) == 2 and c4 != c5))
        score += twoAdj*( (c0 == c6 == 1) + (c4 == c5 == 1))
        score -= twoAdj*( (c0 == c6 == 2) + (c4 == c5 == 2))
            
    if c4 == 0:
        #score += centre
        score += oneAdj*( ((c0 + c8) == 1) + ((c2 + c6) == 1) + ((c1 + c7) == 1) + ((c3 + c5) == 1))
        score -= oneAdj*( ((c0 + c8) == 2 and c0 != c8) + ((c2 + c6) == 2 and c2 != c6) + ((c1 + c7) == 2 and c1 != c7) + ((c3 + c5) == 2 and c3 != c5))
        score += twoAdj*( (c0 == c8 == 1) +(c2 == c6 == 1) +(c1 == c7 == 1) +(c3 == c5 == 1))
        score -= twoAdj*( (c0 == c8 == 2) +(c2 == c6 == 2) +(c1 == c7 == 2) +(c3 == c5 == 2))
            
    if c5 == 0:
        #score += edge
        score += oneAdj*( ((c3 + c4) == 1) + ((c2 + c8) == 1))
        score -= oneAdj*( ((c3 + c4) == 2 and c3 != c4) + ((c2 + c8) == 2 and c2 != c8))
        score += twoAdj*( (c3 == c4 == 1) + (c2 == c8 == 1))
        score -= twoAdj*( (c3 == c4 == 2) + (c2 == c8 == 2))
            
    if c6 == 0:
        #score += corner
        score += oneAdj*( ((c0 + c3) == 1) + ((c2 + c4) == 1) + ((c7 + c8) == 1))
        score -= oneAdj*( ((c0 + c3) == 2 and c0 != c3) + ((c2 + c4) == 2 and c2 != c4) + ((c7 + c8) == 2 and c7 != c8))
        score += twoAdj*( (c0 == c3 == 1) + (c2 == c4 == 1) + (c7 == c8 == 1))
        score -= twoAdj*( (c0 == c3 == 2) + (c2 == c4 == 2) + (c7 == c8 == 2))
            
    if c7 == 0:
        #score += edge
        score += oneAdj*( ((c1 + c4) == 1) + ((c6 + c8) == 1))
        score -= oneAdj*( ((c1 + c4) == 2 and c1 != c4) + ((c6 + c8) == 2 and c6 != c8))
        score += twoAdj*( (c1 == c4 == 1) + (c6 == c8 == 1))
        score -= twoAdj*( (c1 == c4 == 2) + (c6 == c8 == 2))
            
    if c8 == 0:
        #score += corner
        score += oneAdj*( ((c0 + c4) == 1) + ((c2 + c5) == 1) + ((c6 + c7) == 1))
        score -= oneAdj*( ((c0 + c4) == 2 and c0 != c4) + ((c2 + c5) == 2 and c2 != c5) + ((c6 + c7) == 2 and c6 != c7))
        score += twoAdj*( (c0 == c4 == 1) + (c2 == c5 == 1) + (c6 == c7 == 1))
        score -= twoAdj*( (c0 == c4 == 2) + (c2 == c5 == 2) + (c6 == c7 == 2))
    
    pos.data.as_floats[ind/9] = score
    
cdef int basic(array state, array choices, array box, array pos, int lastChoice, char nextPlayer, array bigState) nogil:
    cdef int i, j=0, k, boxNo = lastChoice%9, nextChoice = -1
    cdef float notFull=0, randF=0, runSum=0
    
    """
    1) consider value of 1/2 COMPLETABLE adjacents from both sides
    2) consider value of centre/corner/edge
    3) consider value of next box from both sides NOT DONE
    4) full/won box pos cannot be 50, when full/won hard assign score 
    4) adjusting value of scores, first time 2x, after 1x
    4) significance of small box vs big box
    5) evaluating big box
    prone to block?
    """
    
    if bigState.data.as_chars[boxNo] == 0:  #ensure big box is not taken
        boxNo *= 9
        for i in range(9):
            if state.data.as_chars[i+boxNo] == 0:                   #slot is empty
                if nextPlayer == 1:                                 #account for positional advantages
                    box.data.as_floats[i] = pos.data.as_floats[i]   
                else:
                    box.data.as_floats[i] = -pos.data.as_floats[i]
                notFull += 1
            else:
                box.data.as_floats[i] = 0
        
        if notFull == 0:                    #ensure box is not full
            return(-1)
            
        evaluateSquare(state, box, boxNo)   #evaluate scores for box
        for i in range(9):                  
            if box.data.as_floats[i] < 0 or pos.data.as_floats[i] == 1000000 and box.data.as_floats[i] != 0:   
                box.data.as_floats[i] = 1   #scores >= 0, even if score is trash or next box is filled
            randF += box.data.as_floats[i]
            
        randF *= (rand()/<float>RAND_MAX)
        for i in range(9):                  #choice probability proportional to scores
            runSum += box.data.as_floats[i]
            if runSum >= randF:
                nextChoice = i+boxNo
                #print(box, state[boxNo:boxNo+9], nextChoice, randF)
                break
    
    if nextChoice == -1:                        #choices anywhere if allocated box is full or is won
        for i in range(9):
            if bigState.data.as_chars[i] == 0:  #account if big box is taken
                for k in range(i*9, i*9+9):
                    if state.data.as_chars[k] == 0:
                        choices.data.as_ints[j] = k
                        j += 1
        if j>0:                                 #not all boxes are solved
            nextChoice = choices.data.as_ints[ <int> (j*rand()/<float>(RAND_MAX+1)) ]
    
    if nextChoice != -1:                        #apply change if choice is found
        state.data.as_chars[nextChoice] = nextPlayer
    
    if pos.data.as_floats[lastChoice%9] != 1000000:
        evaluatePosition(state, pos, lastChoice%9 * 9)  #position advantages evaluated right after state is updated
    
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
    
    for i from 0 <= i < treeLen by 6:
        if tree.data.as_ints[i] == parentInd:
            
            if tree.data.as_ints[i+2] == 0:     #indicates infinite UCB
                return(-i)
            #nodeWins / nodeRuns + c * sqrt(ln(parentRuns) / nodeRuns)
            ucb = <float>tree.data.as_ints[i+1]/tree.data.as_ints[i+2] + c * ( log(parentRuns)/tree.data.as_ints[i+2])**0.5
            
            if ucb > maxUCB:
                maxUCB = ucb
                maxInd = i
    
    return(maxInd)

cdef int rollOut(array leafState, int leafChoice, char leafPlayer, int runs):  #state has to be 81 long
    cdef array state, bigState, choices, box
    cdef int i, j, run, lastChoice = leafChoice, wins = 0
    cdef char nextPlayer = leafPlayer, winner
    
    state = clone(array('b'), 81, False)    #initiallise leaf state and bigState to track win condition
    bigState = clone(array('b'), 9, False)
    choices = clone(array('i'), 81, False)  #initialise choices array for randomState()
    box = clone(array('f'), 9, False)
    pos = clone(array('f'), 9, False)       #records strength of positions
    
    with nogil:
        for run in range(runs):
        
            for i in range(81):                     #reset
                state.data.as_chars[i] = leafState.data.as_chars[i]
            lastChoice = leafChoice
            nextPlayer = leafPlayer
            for i in range(9):                      #check win condition
                bigState.data.as_chars[i] = findWin(state, i*9)
                evaluatePosition(state, pos, i*9)
            winner = findWin(bigState, 0)
                
            while winner == 0:
                
                #lastChoice = randomState(state, choices, lastChoice, nextPlayer, bigState) #choose random valid step, updates state
                lastChoice = basic(state, choices, box, pos, lastChoice, nextPlayer, bigState)
                
                #showState(state)
                #print(lastChoice+10, pos)
                
                if lastChoice == -1:        #no other steps available, game ends with draw
                    #print("DRAW")
                    
                    for i in range(81):
                        state.data.as_chars[i] = leafState.data.as_chars[i]
                    lastChoice = leafChoice
                    nextPlayer = leafPlayer
                    #bigState = clone(array('b'), 9, False)
                    for i in range(9):
                        bigState.data.as_chars[i] = 0
                        pos.data.as_floats[i] = 0
                    continue
                    
                for i in range(9):                  #check win condition
                    if bigState.data.as_chars[i] == 0:
                        bigState.data.as_chars[i] = findWin(state, i*9)
                        
                        if bigState.data.as_chars[i] == 0:
                            for j in range(i*9, i*9+9):     #full but no winner
                                if state.data.as_chars[j] == 0:
                                    break
                            else:
                                bigState.data.as_chars[i] = -1
                            
                        if bigState.data.as_chars[i] != 0:
                            pos.data.as_floats[i] = 1000000
                winner = findWin(bigState, 0)
                #print(bigState)
                
                if nextPlayer == 1:                 #update next player
                    nextPlayer = 2
                else:
                    nextPlayer = 1
                
            if winner != leafPlayer:
                wins += 1
    
    #print('winner %s/%s, wins %s/%s' %(winner, leafPlayer, wins, runs))
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
        
        #print('\n')
        #for k in range(0, len(tree), 6):
            #print('parent %s, wins %s, runs %s, stateind %s, lastchoice %s, nextplayer %s' %(tree[k], tree[k+1], tree[k+2], tree[k+3], tree[k+4], tree[k+5]) )
        
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
            #print('Not visited, doing a play out on %s' %leafInd)
        
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
            #print('Expanding on %s' %leafInd)
        
        #wins = rollOut(currState, lastChoice, nextPlayer, 8) #random plays till a side wins
        #backProp(tree, lastChoice, leafInd, wins, 8)
        #"""
        with ThreadPoolExecutor(8) as exe:
            jobs = [exe.submit(rollOut, currState, lastChoice, nextPlayer, 1)]
        wins = 0
        for job in jobs:
            wins += job.result()
        #print(wins)
        backProp(tree, lastChoice, leafInd, wins, 8*1)
        #"""
        #print('winner is %s' %winner)
        #k = leafInd
        #print('parent %s, wins %s, runs %s, stateind %s, lastchoice %s, nextplayer %s' %(tree[k], tree[k+1], tree[k+2], tree[k+3], tree[k+4], tree[k+5]) )
    return( tree.data.as_ints[calculateUCB(tree, 0, 2)+4] )
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
        
def generateStates2(array state, int lastChoice, char nextPlayer, int parent, int stateInd):   #0 means nothing placed
    cdef array newStates = array('b'), newNodes
    newNodes = clone(array('i'), 54, False)
    
    cdef int i, j = 0, boxNo = lastChoice%9 * 9, otherPlayer
    if nextPlayer == 1:
        otherPlayer = 2
    else:
        otherPlayer = 1
    
    for i in range(boxNo, boxNo + 9):
        if state.data.as_chars[i] == 0:
            state.data.as_chars[i] = nextPlayer
            
            extend(newStates, state)
            newNodes.data.as_ints[j] = parent               #parent index
            newNodes.data.as_ints[j+1] = 0                  #wins
            newNodes.data.as_ints[j+2] = 0                  #runs
            newNodes.data.as_ints[j+3] = stateInd + 81*j/6  #corresponding state index
            newNodes.data.as_ints[j+4] = i
            newNodes.data.as_ints[j+5] = otherPlayer
            j += 6
            
            state.data.as_chars[i] = 0
    
    del newNodes[j:]
    return(newStates, newNodes)
    
cdef array generateStates3(array state, array tree, int treeLen, int lastChoice, char nextPlayer, int parent, int stateInd):   #0 means nothing placed
    cdef array newStates = array('b')
    resize(tree, treeLen + 54)
    
    cdef int i, j = treeLen, boxNo = lastChoice%9 * 9, otherPlayer
    if nextPlayer == 1:
        otherPlayer = 2
    else:
        otherPlayer = 1
    
    for i in range(boxNo, boxNo + 9):
        if state.data.as_chars[i] == 0:
            state.data.as_chars[i] = nextPlayer
            
            extend(newStates, state)
            tree.data.as_ints[j] = parent               #parent index
            tree.data.as_ints[j+1] = 0                  #wins
            tree.data.as_ints[j+2] = 0                  #runs
            tree.data.as_ints[j+3] = stateInd + 81*(j-treeLen)/6  #corresponding state index
            tree.data.as_ints[j+4] = i
            tree.data.as_ints[j+5] = otherPlayer
            j += 6
            
            state.data.as_chars[i] = 0
    
    resize(tree, j)
    return(newStates)
"""
MONTE CARLO TREE SEARCH ITERATION:

UCB = nodeWins / nodeRuns + c * sqrt(ln(parentRuns) / nodeRuns)

1) Calculate UCB values and find leaf with maximum, not visted = infinite
2) Not visited, do a roll out, back prop values
3) Visited, do expansion at higher UCB value, choose one at random and roll out

- have not consider if box is filled when expansion
- use a stronger rollout function
"""