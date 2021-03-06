#!/usr/bin/env python
'''Retrieve definitive F10.7 flux and Kp data, and append to RamIndices input file
'''
import datetime as dt
import re, ftplib, cStringIO
import numpy as np

def floatkp(kpstring):
    n = int(kpstring[0])
    dlt = 0
    if len(kpstring)>1:
        kpsym = kpstring[1]
        if kpsym == '-':
            dlt = -0.3
        elif kpsym.lower() == 'o':
            dlt = 0
        elif kpsym == '+':
            dlt = 0.3
        else:
            raise Exception(kpsym + ' is not a recognized symbol')

    return n+dlt

#read file and get last date
with open('../input/RamIndices.txt','r') as fh:
    inds = fh.readlines()
lastline = inds[-1].strip()
lastdatestr = lastline.split()[0]
lastdate = dt.datetime.strptime(lastdatestr, '%Y%m%d')

#get list of dates required
j2000date = dt.datetime(2000,1,1)
j2000jd = 2451544.5

currdate = dt.datetime.now()
ndaysreq = (currdate-lastdate).days
startjd = j2000jd + 1 + (lastdate-j2000date).days
endjd = j2000jd + (currdate-j2000date).days
#print(startjd, endjd)

outJDs = [startjd + n + 0.5 for n in xrange(int(endjd-startjd))] #add a half to make noontime flux
outdates = [lastdate+dt.timedelta(days=n+1) for n in xrange(int(endjd-startjd))]

#download updated F10.7 from ftp://ftp.geolab.nrcan.gc.ca/data/solar_flux/daily_flux_values/fluxtable.txt
#only has data from 2004-10-28 (prior data are in different files)
io_store = cStringIO.StringIO()
ftp = ftplib.FTP('ftp.geolab.nrcan.gc.ca')
ftp.login()
ftp.cwd('data/solar_flux/daily_flux_values')
ftp.retrlines('RETR {0}'.format('fluxtable.txt'), io_store.write)
io_store.seek(0)
conts = io_store.read()

#get first line of data (needs regex as no linebreaks & odd spacing
#then split up, read dates, interpolate to requested JDs
char1idx = re.search('\d', conts).start()
conts = conts[char1idx:].split()
jds = np.array(conts[2::7]).astype(float)
#atmflux = np.array(conts[4::7]).astype(float)  #F10.7 observed flux adjusted for atmospheric loss (i.e. estimate for top of atmosphere)
#ursiflux = np.array(conts[6::7]).astype(float) #URSI Series D flux specification
AU1flux = np.array(conts[5::7]).astype(float)  #F10.7 normalized to value at 1AU
outflux = np.interp(outJDs, jds, AU1flux)

#now get Kp values...
#start with first month
year, month = outdates[0].year, outdates[0].month
io_store = cStringIO.StringIO()
ftp = ftplib.FTP('ftp.gfz-potsdam.de')
ftp.login()
ftp.cwd('pub/home/obs/kp-ap/tab')
try:
    ftp.retrlines('RETR kp{0:02d}{1:02d}.tab'.format(year%100,month), io_store.write)
except (ftplib.error_perm):
    exit()
io_store.seek(0)
conts = io_store.read()
kp_thismonth = map(''.join, zip(*[iter(conts)]*49))

#get kp and write output
for od, of in zip(outdates, outflux):
    if (od.year!=year) or (od.month!=month):
        #read new Kp file
        year, month = od.year, od.month
        io_store = cStringIO.StringIO()
        try:
            ftp.retrlines('RETR kp{0:02d}{1:02d}.tab'.format(year%100,month), io_store.write)
        except (ftplib.error_perm):
            break
        io_store.seek(0)
        conts = io_store.read()
        kp_thismonth = map(''.join, zip(*[iter(conts)]*49))
    #use current Kp file (was updated if not current)
    useline = [item for item in kp_thismonth if item.startswith('{0:02d}{1:02d}{2:02d}'.format(od.year%100, od.month, od.day))]
    try:
        kpstrs = useline[0].split()[1:9]
    except IndexError:
        #no entry, probably means we hit the last available data
        break

    kpvals = [floatkp(x) for x in kpstrs]
    printme = ''.join(['{0: 2.1f}'.format(k) for k in kpvals])
    with open('../input/RamIndices.txt', 'a') as fh:
        fh.write('{0}{1} {2:05.1f}\n'.format(od.strftime('%Y%m%d'), printme, of))

