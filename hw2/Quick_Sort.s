# Bubble Sort

.data
str1:   .asciiz        "Quick Sort\n"
str2:   .asciiz        "Data before sorting:\n"
str3:   .asciiz        "\nData after sorting:\n"
str4:   .asciiz        ", "
str5:   .asciiz        "\nEnd of Quick Sort!!"
str6:   .asciiz        "\n"
str7:   .asciiz        "pivot: "
.text


.globl my_main
my_main:
############## load data ##############
#{-1, 3, -5, 7, -9, 2, -4, 6, -8, 10} #
#######################################
li         $t0,        -6
sw         $t0,        0($gp)
li         $t0,        7
sw         $t0,        4($gp)
li         $t0,        8
sw         $t0,        8($gp)
li         $t0,        11
sw         $t0,        12($gp)
li         $t0,        5
sw         $t0,        16($gp)
li         $t0,        -6
sw         $t0,        20($gp)
li         $t0,        1
sw         $t0,        24($gp)
li         $t0,        0
sw         $t0,        28($gp)
li         $t0,        -3
sw         $t0,        32($gp)
li         $t0,        -9
sw         $t0,        36($gp)

li         $v0,        4         # print string
la         $a0,        str1      # load string
syscall
la         $a0,        str2      # load string
syscall

# print the data in the array
move       $a0,        $gp       # get address of array_base
li         $a1,        10        # upper bound = 10
jal        printData

# QuickSort
li         $a1,        10        # length of array
move       $a0,        $gp       # address of array_base
jal        QuickSort

li         $v0,        4         # print string
la         $a0,        str3      # load string
syscall
# print the data in the array
move       $a0,        $gp       # get address of array_base
li         $a1,        10        # upper bound = 10
jal        printData

# exit program
j          exit


.globl printData
printData:
    addi       $sp,   $sp,    -12
    sw         $s0    0($sp)               # put $s0 at $sp
    sw         $s1    4($sp)
    sw         $ra    8($sp)

    move       $s0    $a0                  # array address
    move       $s1    $a1                  # length
    li         $t0    0                    # i = 0
    move       $t1    $s0

    beqz       $t0,   L2                   # if(i == 0) skip print ", "
L1:
    li         $v0,   4
    la         $a0,   str4                 # load ", "
    syscall
L2:
    lw         $a0,   ($t1)
    li         $v0,   1                    # print data
    syscall
    addi       $t1,   4                    # next element
    addi       $t0,   1                    # i = i + 1
    blt        $t0,   $s1,    L1           # if(i<10) go to loop
    la         $a0,   str6
    li         $v0,   4
    syscall
    lw         $ra,   8($sp)
    lw         $s1,   4($sp)
    lw         $s0,   0($sp)               # load data at $sp to $s0
    addi       $sp,   $sp,    12
    jr         $ra                         # jump back to main


.globl QuickSort
QuickSort:
############################### C++ code ##################################
# void quicksort(DListNode<T>* left , DListNode<T>* right , size_t size){ #
#    if(size <= 1 )return;                                                #
#    //find the medium data                                               #
#    DListNode<T>* index = left;                                          #
#    for(size_t i=1; i<= size_t(size/2) ; i++)                            #
#         index = index->_next;                                           #
#     //set pivot                                                         #
#     T pivot = index->_data;                                             #
#     //put the pivot data in the rightmost node                          #
#     myswap(index,right);                                                #
#     //keep the position where new smaller data insert to                #
#     DListNode<T>* swapindex = left;                                     #
#     //use index run from left to right->_prev                           #
#     index = left;                                                       #
#     size_t leftlength = 0;                                              #
#     while(index != right){                                              #
#         if(index->_data <= pivot){                                      #
#             //cerr<<index->_data<<endl;                                 #
#             myswap(index , swapindex);                                  #
#             swapindex = swapindex->_next;                               #
#             leftlength++;                                               #
#         }                                                               #
#         index = index->_next;	                                          #
#     }                                                                   #
#     //put the pivot data in the swapindex node                          #
#     //all left nodes have smaller data; right nodes have bigger         #
#     myswap(swapindex,right);                                            #
#     quicksort(left,swapindex->_prev,leftlength-1);                      #
#     quicksort(swapindex->_next , right , size-leftlength);            #
# }                                                                       #
###########################################################################
    # saving registers
    addi       $sp,    $sp,    -28
    sw         $ra,    24($sp)
    sw         $s5,    20($sp)             # for swapindex
    sw         $s4,    16($sp)             # for leftlength
    sw         $s3,    12($sp)             # for length
    sw         $s2,    8($sp)              # for address of array
    sw         $s1,    4($sp)              # for pivot
    sw         $s0,    0($sp)              # for index
    # move parameters
    move       $s2,    $a0                 # $s2 = address of array
    move       $s3,    $a1                 # $s3 = length
    li         $s0,    0                   # $s0 = index = 0
    li         $s4,    0                   # $s4 = leftlength = 0
    li         $s5,    0                   # $s5 = swapindex = 0
    # no need to sort
    li         $t0,    1
    ble        $s3,    $t0,    exitf       # if(n <= 1) return
    # find medium data
    li         $t0,    2
    div        $t0,    $s3,    $t0         # $t0 = n/2
    addi       $t0,    $t0,    -1
    sll        $t1,    $t0,    2
    add        $t2,    $t1,    $s2         # $t2 = v + 4 * (n/2 - 1)
    lw         $s1,    0($t2)              # $s1 = pivot
    # print "pivot:"
    la         $a0,    str7
    li         $v0,    4
    syscall
    move       $a0,    $s1
    li         $v0,    1
    syscall
    la         $a0,    str6
    li         $v0,    4
    syscall
    # put pivot in the rightmost
    move       $a0,    $s2
    li         $t0,    2
    div        $t0,    $s3,    $t0         # $t0 = n/2
    addi       $a1,    $t0,    -1
    addi       $a2,    $s3,    -1          # $a2 = length-1
    jal        swap
    # while loop
while1:
    bge        $s0,    $s3,    exitwhile   # if(index >= length) break
    move       $t0,    $s0
    sll        $t0,    $t0,    2
    add        $t1,    $s2,    $t0         # $t1 = v + 4 * index
    lw         $t2     0($t1)              # $t2 = v[index]
    bge        $t2,    $s1,    noswap
    # swap(index,swapindex)
    move       $a0,    $s2
    move       $a1,    $s0
    move       $a2,    $s5
    jal        swap
    addi       $s5,    1                   # swapindex = swapindex + 1
    addi       $s4,    1                   # leftlength = leftlength + 1

noswap:
    addi       $s0,    1                   # index = index + 1
    j          while1

exitwhile:
    addi       $t0,    $s3,    -1          # $t0 = length-1
    move       $a0,    $s2
    move       $a1,    $t0
    move       $a2,    $s5
    jal        swap

    move       $a0,    $s2
    li         $a1,    10
    jal        printData


    move       $a1,    $s4
#    move       $a0,    $a1
#    li         $v0,    1
#    syscall
#    la         $a0,    str4
#    li         $v0,    4
#    syscall
    move       $a0,    $s2
#    li         $v0,    1
#    syscall
#    la         $a0,    str6
#    li         $v0,    4
#    syscall
    jal        QuickSort

    addi       $t0,    $s4,    1
    sub        $a1,    $s3,    $t0
#    move       $a0,    $a1
#    li         $v0,    1
#    syscall
#    la         $a0,    str4
#    li         $v0,    4
#    syscall
    addi       $t0,    $s5,    1       # swapindex's next
    sll        $t0,    $t0,    2
    add        $a0,    $t0,    $s2
#    li         $v0,    1
#    syscall
#    la         $a0,    str6
#    li         $v0,    4
#    syscall
    jal        QuickSort

exitf:
    lw         $s0,    0($sp)
    lw         $s1,    4($sp)
    lw         $s2,    8($sp)
    lw         $s3,    12($sp)
    lw         $s4,    16($sp)
    lw         $s5,    20($sp)
    lw         $ra,    24($sp)
    addi       $sp,    $sp,    28
    jr         $ra

########## C++ code ###########
#    temp = v[j];             #
#    v[j] = v[k];             #
#    v[k] = temp;             #
# $a0 = the address of array  #
# $a1 = j , $a2 = k           #
###############################
swap:
    move       $t0,    $a0              # $t0 = address
    move       $t1,    $a1              # $t1 = j
    move       $t2,    $a2              # $t2 = k
    sll        $t3,    $t1,    2        # $t3 = $t1 * 4
    sll        $t4,    $t2,    2        # $t4 = $t2 * 4
    add        $t5,    $t0,    $t3      # $t5 = v + 4 * j
    add        $t6,    $t0,    $t4      # $t6 = v + 4 * k
    lw         $t7,    0($t5)           # $t7 = v[j]
    lw         $t8,    0($t6)           # $t8 = v[k]
    sw         $t7,    0($t6)           # v[k] = $t7
    sw         $t8,    0($t5)           # v[j] = $t8
    jr         $ra

.globl exit
exit:
    li         $v0,        4         # print string
    la         $a0,        str5      # load string
    syscall
    li         $v0,        10
    syscall
