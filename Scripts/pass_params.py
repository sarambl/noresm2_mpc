# By Jonah Shaw starting on 19/10/02
# Use pandas to read parameter values from a .csv
# Pass these values to an automated bash script to submit NorESM cases

import pandas as pd
import numpy as np
import os
from datetime import datetime
import sys

def main(csvfile):
    day = datetime.now()
    allstamp = day.strftime("%Y%m%d_%H%M%S_")

    print('Reading from: ', csvfile)

    data = pd.read_csv(csvfile)  # specify the data set here. Format is [casename, runyet, wbf, inp]

    print(data)

    # Iterate over cases, updating the .csv and then calling a bash script to do NorESM things:
    rows, cols = np.shape(data)
    for i in range(rows):
        row = data.loc[i,:]
        print(row)
        if not row[1]: # Check if the case has already been run
            _wbf = str(data.loc[i,'wbf_mult']) # removing the extra zero, bad fix
            _inp = str(data.loc[i,'inp_mult']) 
            if _wbf[-1] == '0': _wbf = _wbf[:-1] # removing the extra zero
            if _inp[-1] == '0': _inp = _inp[:-1]
            _case = str(data.loc[i,'casename'])

            print(_wbf, _inp)
            # adjust .csv so that the case is not resubmitted:
            data.loc[i,'run'] = 1
            data[0:].to_csv(csvfile, sep=',', index = False)  # This needs to be changed to be the original .csv
            casename = allstamp + csvfile[:-4] + "_" + _case
            str_arg = casename + ' ' + _wbf + ' ' + _inp
            print('submitting: ' + str_arg)
            os.system('sh slf_and_inp.sh ' + str_arg) # call bash script
        else: print('all ready run')


if __name__ == "__main__":
   main(sys.argv[1])