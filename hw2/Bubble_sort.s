# Bubble Sort

.data
str1:   .asciiz        "Bubble Sort\n"
str2:   .asciiz        "\nData before sorting:\n"
str3:   .asciiz        "\nData after sorting:\n"
str4:   .asciiz        ", "
.text


.globl my_main
my_main:
############## load data ##############
#{-1, 3, -5, 7, -9, 2, -4, 6, -8, 10} #
#######################################
li         $t0,        -1
sw         $t0,        0($gp)
li         $t0,        3
sw         $t0,        4($gp)
li         $t0,        -5
sw         $t0,        8($gp)
li         $t0,        7
sw         $t0,        12($gp)
li         $t0,        -9
sw         $t0,        16($gp)
li         $t0,        2
sw         $t0,        20($gp)
li         $t0,        -4
sw         $t0,        24($gp)
li         $t0,        6
sw         $t0,        28($gp)
li         $t0,        -8
sw         $t0,        32($gp)
li         $t0,        10
sw         $t0,        36($gp)

li         $v0,        4         # print string
la         $a0,        str1      # load string
syscall
la         $a0,        str2      # load string
syscall

# print the data in the array
move       $t0,        $gp       # get address of array_base
li         $t1,        0         # i = 0
li         $a1,        10        # upper bound = 10
jal        printData

# bubbleSort
li         $a1,        10        # length of array
move       $a0,        $gp       # address of array_base
jal        bubbleSort

li         $v0,        4         # print string
la         $a0,        str3      # load string
syscall
# print the data in the array
move       $t0,        $gp       # get address of array_base
li         $t1,        0         # i = 0
li         $a1,        10        # upper bound = 10
jal        printData

# exit program
j          exit


.globl printData
printData:
    beqz       $t1,   L1                   #if(i == 0) skip print ", "
    li         $v0,   4
    la         $a0,   str4                 # load ", "
    syscall
L1:
    lw         $a0,   ($t0)
    li         $v0,   1                    # print data
    syscall
    addi       $t0,   4                    # next element
    addi       $t1,   1                    # i = i + 1
    blt        $t1,   $a1,    printData    # if(i<10) go to loop
    jr         $ra                         # jump back to main


.globl bubbleSort
bubbleSort:
######################### C++ code ############################
# void sort (int v[], int n)                                  #
# {                                                           #
#     int i, j;                                               #
#     for (i = 0; i < n; i += 1) {                            #
#         for (j = i – 1; j >= 0 && v[j] > v[j + 1]; j -=1){  #
#             swap(v,j);                                      #
#         }                                                   #
#     }                                                       #
# }                                                           #
###############################################################
    addi       $sp,    $sp,    -20
    sw         $ra,    16($sp)
    sw         $s3,    12($sp)
    sw         $s2,    8($sp)
    sw         $s1,    4($sp)
    sw         $s0,    0($sp)
    move       $s2,    $a0             # store the address of array
    move       $s3,    $a1             # store length
    li         $s0,    0               # i = 0
fori:
    bge        $s0,    $s3,    exiti
    jr         $ra
    addi       $s1,    $s0,    -1

exitj:
    addi       $s0,    $s0,    1
    j          fori

exiti:
    lw         $s0,    0($sp)
    lw         $s1,    4($sp)
    lw         $s2,    8($sp)
    lw         $s3,    12($sp)
    lw         $ra,    16($sp)
    addi       $sp,    $sp,    20

    jr         $ra

.globl exit
exit:
    li         $v0,        10
    syscall
