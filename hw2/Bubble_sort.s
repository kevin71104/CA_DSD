#############################################################
#                Computer Architecture 2017                 #
#                Hw2 : MIPS implementation                  #
#                       Bubble Sort                         #
#############################################################

.data
str1:   .asciiz        "\nStart Bubble Sort\n\n"
str2:   .asciiz        "Data before sorting:\n"
str3:   .asciiz        "Data after sorting:\n"
str4:   .asciiz        ", "
str5:   .asciiz        "\nEnd of Bubble Sort!!"
str6:   .asciiz        "\n"
str7:   .asciiz        "pivot: "
str8:   .asciiz        "Please input the length of the array: \n"
str9:   .asciiz        "Please input the elements of the array: \n"

.text

############## sort data ###############
# {-1, 3, -5, 7, -9, 2, -4, 6, -8, 10} #
########################################
.globl my_main
my_main:
li         $v0,        4
la         $a0,        str8
syscall

# Get the length of the array
li         $v0,        5
syscall
move       $s7,        $v0          # store the length in $s7

# Get the dynamic memory
move       $t0,        $s7
sll        $t1,        $t0,    2
li         $v0,        9
move       $a0,        $t1
syscall
move       $s1,        $v0          # store the address in $s1

# Get the elements of the array
li         $v0,        4
la         $a0,        str9
syscall

move       $a0,        $s7
move       $a1,        $s1
jal        readData

# print the unsorted data in the array
li         $v0,        4            # print string
la         $a0,        str1         # load string
syscall
la         $a0,        str2
syscall

move       $a0,        $s1          # get address of array_base
move       $a1,        $s7          # upper bound = length
jal        printData

# BubbleSort
move       $a1,        $s7          # length of array
move       $a0,        $s1          # address of array_base
jal        bubbleSort

li         $v0,        4            # print string
la         $a0,        str3         # load string
syscall

# print the sorted data in the array
move       $a0,        $s1          # get address of array_base
move       $a1,        $s7          # upper bound = length
jal        printData

# exit program
j          exit

.globl readData
readData:
    addi       $sp,   $sp,    -12
    sw         $s0,   0($sp)
    sw         $s1,   4($sp)
    sw         $ra,   8($sp)

    move       $s0,   $a0                 # length
    move       $s1,   $a1                 # address
    li         $t0,   0
loop:
    bge        $t0,   $s0,    exitRead
    sll        $t1,   $t0,    2
    add        $t2,   $s1,    $t1
    li         $v0,   5
    syscall
    sw         $v0,   0($t2)
    addi       $t0,   1
    j          loop
exitRead:
    lw         $ra,   8($sp)
    lw         $s1,   4($sp)
    lw         $s0,   0($sp)
    jr         $ra

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



######################### C++ code ############################
# void sort (int v[], int n)                                  #
# {                                                           #
#     int i, j;                                               #
#     for (i = 0; i < n; i += 1) {                            #
#         for (j = i – 1; j >= 0 && v[j] > v[j + 1]; j -= 1){ #
#             swap(v,j);                                      #
#         }                                                   #
#     }                                                       #
# }                                                           #
###############################################################
.globl bubbleSort
bubbleSort:
# $a0 : address of array
# $a1 : length
# saving registers
    addi       $sp,    $sp,    -20
    sw         $ra,    16($sp)
    sw         $s3,    12($sp)
    sw         $s2,    8($sp)
    sw         $s1,    4($sp)
    sw         $s0,    0($sp)
# move parameters
    move       $s2,    $a0             # s2 = address of array
    move       $s3,    $a1             # s3 = length
    li         $s0,    0               # i = 0
fori:
    bge        $s0,    $s3,    exiti   # if( i >= 10 ) jump to exiti
    addi       $s1,    $s0,    -1      # j = i - 1
forj:
    blt        $s1,    $zero,  exitj   # if(j < 0) exit j-loop
    sll        $t0,    $s1,    2       # $t0 = j * 4
    add        $t1,    $t0,    $s2     # $t1 = v + 4*j
    lw         $t2,    0($t1)          # $t2 = v[j]
    lw         $t3,    4($t1)          # $t3 = v[j+1]
    bge        $t3,    $t2,    exitj   # if(v[j+1] > v[j]) exit j-loop
# swap(v,j)
    move       $a0,    $s2             # parameter: address of array
    move       $a1,    $s1             # parameter: index
    jal        swap
    
    addi       $s1,    $s1,    -1      # j = j - 1
    j          forj
exitj:
    addi       $s0,    $s0,    1       # i = i + 1
    j          fori

exiti:
    lw         $s0,    0($sp)
    lw         $s1,    4($sp)
    lw         $s2,    8($sp)
    lw         $s3,    12($sp)
    lw         $ra,    16($sp)
    addi       $sp,    $sp,    20
    jr         $ra

########## C++ code ###########
#    temp = v[j];             #
#    v[j] = v[j+1];           #
#    v[j+1] = temp;           #
###############################
swap:
    sll        $t0,    $a1,    2        # $t0 = j * 4
    add        $t0,    $t0,    $a0      # $t0 = v + j * 4
    lw         $t1,    0($t0)           # $t1 = v[j]
    lw         $t2,    4($t0)           # $t2 = v[j+1]
    sw         $t2,    0($t0)           # v[j] = $t2
    sw         $t1,    4($t0)           # v[j+1] = $t1
    jr         $ra

.globl exit
exit:
    li         $v0,        4         # print string
    la         $a0,        str5      # load string
    syscall
    li         $v0,        10
    syscall
