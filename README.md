###  Fake RISC-V CPU
MS108, Computer Architecture project in ACM class. Just try something new instead of simply copying seniors' designs. 

**pitfall** *Bigger and dumber is better.* 

**pitfall** *Sometimes smarter is better than bigger and dumber.* 

#### Feature

* Tomasulo algorithm (with ROB and branch bits)
* Pipeline: 5 stages
* A 1KiB I-cache, directly mapped
* A write-back D-cache supported
* Branch prediction supported and virtual regfile to support it. Branch prediction policy is Gshare
* Precise Interruption unsupported but easy to fix(faster if not fix, and the assignment does not require)
* Running on FPGA with 80MHz, and 100MHz frequency is also supported

#### Mention: 

* Virtual memory, CSR(control and status register) instructions, timers and counters, environment call and breakpoints unsupported, so cannot run an OS on it. (no time to improve and cannot achieve on my FPGA, so I give up)

* The main problem is that my FPGA cannot make sense when the structure becomes complex, so the frequency needs to slow down, making complex design unable to work well(Even a global&local branch prediction with a 512B I-cache can make the delay too high). 

#### Summary: 

* The most interesting thing I notice(though not the most important) is that the restriction comes from the situation that when adding a new instruction into the RS, the ready will be correct a cycle later, making the instruction without any hazard wait for a cycle. This leads to an innovation of my design. 

* The biggest problem is that I do not understand how Vivado works to design, even simply removing some register may lead to a  higher delay, and, the strangest, **more LUT**. 

    <font size=1>Consider this condition: I repeat calculating something in 32 units(see the head, tail and nxtTail in regfile/regfileLine), but if I calculate them outside and send the result to each unit, The LUT useage increases considerably. </font>

#### Remark: 

* I've also tried some more complex cache designs and branch predictions, but they may not work well on the testbench (or be restricted by my FPGA), so I remove them and left a copy in the /backup/Units. 

#### References:

1. https://github.com/riscv-boom/riscv-boom, an out of order RISC-V CPU using chisel, with branch bits(named branch mask there)
2. http://www.kroening.com/diplom/diplom/main003.html, details about the hardware of Tomasulo Architecture.
