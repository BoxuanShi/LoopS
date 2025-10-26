Get["mm/FireReconstruct.wl"];


data = ConstantArray[{(d^15+1)/(d^15-1)}, 10^5]


dataAsFireTable = matrixToFireTable[data]


Put[dataAsFireTable, "examples/large_table_one_var.tables"]
