Pipelined MIPS

Files in common:

- CHIP.v			
Top module of our design, including MIPS_Pipeline, I_cache, and D_cache	

- MIPS_Pipeline.v         
design for MIPS_Pipeline to handle the required instructions 

- cache.v                 
cache module for I_cache and D_cache


- src/baseline/           
all .v file, .sdf file and .ddc file to meet baseline requirement
You can run tb directly

- src/L2Cache/            
all .v file, .sdf file and .ddc file to meet L2cache extention requirement
You can run tb directly 

- src/MULT_DIV/           
all .v file, .sdf file and .ddc file to meet MultDiv extention requirement
You can run tb directly 

- src/BrPred/           
all .v file, .sdf file and .ddc file to meet BrPred requirement
You can run tb directly

