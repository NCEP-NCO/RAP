perl -pi -e "s/_00/_\%CYC\%/g" $1
perl -pi -e "s/cyc=00/cyc=\%CYC\%/g" $1
perl -pi -e "s/=prod/=\%ENVIR\%/g" $1
perl -pi -e "s/output\/prod/output\/\%ENVIR\%/g" $1
perl -pi -e "s/RAP-OPS/\%PROJ\%/g" $1
perl -pi -e "s/-J j/-J \%E\%/g" $1
perl -pi -e "s/\"\/ecf\/ecfnets\/scripts\/head.h\"/<head.h>/g" $1
perl -pi -e "s/\"\/ecf\/ecfnets\/scripts\/tail.h\"/<tail.h>/g" $1
