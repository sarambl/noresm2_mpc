# By Jonah Shaw starting on 19/10/02
# Use pandas to read parameter values from a .csv
# Pass these values to an automated bash script to submit NorESM cases

import pandas as pd
import numpy as np
import os
from datetime import datetime

day = datetime.now()
daystamp = day.strftime("/%Y%m%d")
tstamp = day.strftime("%H%M%S")
allstamp = day.strftime("%Y%m%d_%H%M%S_")

param_set = "sample_param_set.csv"

data = pd.read_csv(param_set)  # specify the data set here. Format is [casename, runyet, wbf, inp]

# Testing functionality...
# data.loc[2,'run'] = 1
# data.loc[5,'run'] = 1
# data.loc[6,'run'] = 1

print(data)

# Iterate over cases, updating the .csv and then calling a bash script to do NorESM things:
rows, cols = np.shape(data)
for i in range(rows):
    row = data.loc[i,:]
    # print(row)
    if not row[1]: # Check if the case has already been run
        # print(data)
        _slf = str(data.loc[i,'slf_mult'])
        _inp = str(data.loc[i,'inp_mult'])
        _case = str(data.loc[i,'casename'])
        # adjust .csv so that the case is not resubmitted:
        data.loc[i,'run'] = 1
        data[0:].to_csv(param_set, sep=',', index = False)  # This needs to be changed to be the original .csv
        casename = allstamp + param_set[:-4] + "_" + _case
        wbf_arg = 'wbf_tag = ' + _slf # probably doesn't work
        inp_arg = 'inp_tag = ' + _inp
        str_arg = casename + ' ' + _slf + ' ' + _inp
        print('submitting: ' + str_arg)
        os.system('sh slf_and_inp.sh ' + str_arg) # call bash script
    else: print('all ready run')