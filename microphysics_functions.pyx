import numpy as np
cimport numpy as np

from libc.math cimport fmax

from thermodynamic_functions cimport *
include "parameters.pxi"

cdef double r2q(double r_, double qt) nogil :
    """ 
    Convert mixing ratio to specific humidity assuming
    qd = 1 - qt
    qt = qv + ql + qi
    qr = mr/md+mv+ml+mi
    """
    return r_ * (1. - qt) 
 
cdef double q2r(double q_, double qt) nogil :
    """ 
    Convert specific humidity to mixing ratio
    see r2q for assumptions
    """
    return q_ / (1. - qt)


cdef double rain_source_to_thetal(double qr, double p0, double T) nogil :
    """
    Source term for thetal because of ql turning to qr and disappearing from the working fluid
    """
    return qr / exner_c(p0) * latent_heat(T) / cpd

# instantly convert all cloud water exceeding a threshold to rain water 
# the threshold is specified as axcess saturation
# rain water is immediately removed from the domain
# Tiedke:   TODO - add reference
cdef double acnv_instant(double ql, double qt, double sat_treshold, double T, double p0) nogil :

    cdef double psat = pv_star(T)
    cdef double qsat = qv_star_c(p0, qt, psat)

    return fmax(0.0, ql - sat_treshold * qsat)


# time-rate expressions for 1-moment microphysics
# autoconversion:   Kessler 1969, see Table 1 in Wood 2005: https://doi.org/10.1175/JAS3530.1
# accretion, rain evaporation rain terminal velocity: 
#    Grabowski and Smolarkiewicz 1996 eqs: 5b-5d
#    https://doi.org/10.1175/1520-0493(1996)124<0487:TTLSLM>2.0.CO;2

# unfortunately the rate expressions in the paper are for mixing ratios
# need to convert to specific humidities

# TODO - change it to saturation treshold
cdef double acnv_rate(double ql, double qt) nogil :

    cdef double rl = q2r(ql, qt)

    return (1. - qt) * 1e-3 * fmax(0.0, rl - 5e-4)
    #      dq/dr     * dr/dt

cdef double accr_rate(double ql, double qr, double qt) nogil :

    cdef double rl = q2r(ql, qt)
    cdef double rr = q2r(qr, qt)

    return (1. - qt) * 2.2 * rl * rr**0.875
    #      dq/dr     * dr/dt

cdef double evap_rate(double rho, double qv, double qr, double qt, double T, double p0) nogil :

    cdef double psat = pv_star(T)
    cdef double qsat = qv_star_c(p0, qt, psat)
    cdef double rr   = q2r(qr, qt)
    cdef double rv   = q2r(qv, qt)
    cdef double rsat = q2r(qsat, qt)

    cdef double C = 1.6 + 124.9 * (1e-3 * rho * rr)**0.2046 # ventilation factor

    return (1 - qt) * (1. - rv/rsat) * C * (1e-3 * rho * rr)**0.525 / rho / (540 + 2.55 * 1e5 / (p0 * rsat))
    #      dq/dr     * dr/dt

cdef double terminal_velocity(double rho, double rho0, double qr, double qt) nogil :
    
    cdef double rr = q2r(qr, qt)    

    return 14.34 * rho0**0.5 * rho**-0.3654 * rr**0.1346
