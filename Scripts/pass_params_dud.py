# By Jonah Shaw starting on 19/10/02
# Use pandas to read parameter values from a .csv
# Pass these values to an automated bash script to submit NorESM cases

import pandas as pd
import numpy as np
import os
from datetime import datetime
import sys

def main():
    day = datetime.now()
    allstamp = day.strftime("%Y%m%d_%H%M%S_")

    # print('Reading from: ', csvfile)

    # data = pd.read_csv(csvfile)  # specify the data set here. Format is [casename, runyet, wbf, inp]

    # print(data)

    # Iterate over cases, updating the .csv and then calling a bash script to do NorESM things:
    
    str_arg = allstamp + 'dud' + ' ' + '1.0' + ' ' + '1.0'
    print(str_arg)

    os.system('sh slf_and_inp_dud.sh ' + str_arg) # call bash script


if __name__ == "__main__":
    main()