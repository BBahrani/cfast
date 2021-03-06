
! --------------------------- cenviro -------------------------------------------

module cenviro
    
    use precision_parameters
    use cfast_types
    use cparams
    implicit none
    save
    
    integer :: jaccol, neqoff

    integer, parameter :: constvar = 1 ,odevara = 2 ,odevarb = 4, odevarc = 8
    integer, parameter :: eqp = 1, eqpmv = 2, eqtmv = 3, eqtu = 4, eqvu = 5, eqtl = 6, eqoxyl = 7, eqoxyu = 8, eqtt = 9, eqwt = 10
    
    logical izdtflag, izcon(nr), izhvac(nr)
    
    real(eb), dimension(nr) :: zzrelp, zzpabs
    real(eb), dimension(nr,2) :: zzvol, zzhlay, zztemp, zzrho, zzmass, zzftemp
    real(eb), dimension(nr,2,ns) :: zzgspec, zzcspec
    real(eb), dimension(nr,nwal) :: zzwspec
    real(eb), dimension(nr,nwal,2) :: zzwtemp
    real(eb), dimension(mxhvsys,ns) :: zzhvpr
    real(eb), dimension(mxhvsys) :: zzhvm
    real(eb), dimension(nr,4) :: zzwarea
    real(eb), dimension(nr,10) :: zzwarea2
    real(eb), dimension(mxcross,nr) :: zzrvol, zzrarea, zzrhgt
    real(eb), dimension(2,nr) :: zzabsb, zzbeam
    real(eb), dimension(0:mxpts+1) :: zzdisc
    real(eb), dimension(nr,nr) :: zzhtfrac
    real(eb) :: zzdtcrit

    real(eb) :: interior_density, exterior_density, interior_temperature, exterior_temperature
 
    integer, dimension(ns+2) :: izpmap
    integer, dimension(2,nr) :: izwmap
    integer, dimension(4,nr) :: izwmap2
    integer, dimension(nr,4) :: izswal
    integer, dimension(4*nr,5) :: izwall
    integer, dimension(nr) :: izrvol, iznwall(nr), izshaft(nr)
    integer, dimension(0:nr) :: izheat
    integer, dimension(nr,0:nr) :: izhtfrac
    integer :: izdtnum,izdtmax, izndisc, nswal
    
end module cenviro

! --------------------------- cfast_main -------------------------------------------

module cfast_main
    use precision_parameters
    use cfast_types  
    use cparams
    use dsize
    implicit none
    save
    
    integer :: hvorien(mxext), hvnode(2,mxext), mpsdat(3), ivvent_connections(nr,nr), na(mxbranch), nofsets(13), &
        ncnode(mxnode), ne(mxbranch), mvintnode(mxnode,mxcon), icmv(mxnode,mxcon), nfc(mxfan), ihvent_connections(nr,nr), &
        nslb(nwal,nr), nf(mxbranch), vshape(nr,nr), objrm(0:mxfires), objign(mxfires), numnode(mxslb+1,4,nr), &
        froom(0:mxfire), numobjl, ixdtect(mxdtect,dticol), iquench(nr), idtpnt(nr,2), &
        ndtect, idset, ntarg, ifroom(mxfire), ifrpnt(nr,2), ibrd(mxduct), nfire, ijk(nr,nr,mxccv), &
        nventijk,nfopt,vface(mxhvents), lcopyss,heatfr, nfilter, obj_fpos(0:mxfires)
    
    integer :: nofp, nofpmv, noftmv, noftu, notvu, noftl, nofoxyl, nofoxyu, notwt, nofprd, &
        nofhvpr, nequals, noffsm, nlspct, ivers, lfmax, lfbt, nopmx, nrflow, lprint, nsmax, lsmv, itmmax, idiag, &
        nofvu, nofwt, nm1, n, n2, n3, n4, itmstp, ndt, next, nnode, nft, nfan, nbr
    
    equivalence (nofp,nofsets(1)), (nofpmv,nofsets(2)), (noftmv,nofsets(3)), (noftu,nofsets(4)), (nofvu,nofsets(5)), &
        (noftl,nofsets(6)), (nofoxyl,nofsets(7)), (nofoxyu,nofsets(8)), (nofwt,nofsets(9)), &
        (nofprd,nofsets(10)), (nofhvpr,nofsets(11)), (nequals,nofsets(12)), (noffsm,nofsets(13))

    real(eb) :: mass(2,nr,ns), minmas, lower_o2_limit, qf(nr), p(maxteq), objmaspy(0:mxfire), tradio, &
        heatup(nr), heatlp(nr),  vvarea(nr,nr), hveflo(2,mxext), hveflot(2,mxext), &
        hhp(mxhvents), bw(mxhvents), hh(mxhvents), hl(mxhvents), ventoffset(mxhvents,2), oplume(3,mxfires),  &
        qcvh(4,mxhvents),qcvv(4,mxvvents),qcvm(4,mxfan), &
        vmflo(nr,nr,2), xdtect(mxdtect,dtxcol), qspray(0:mxfire,2), &
        radio(0:mxfire), xfire(mxfire,mxfirp), rdqout(4,nr),objxyz(4,mxfires), radconsplit(0:mxfire),heatfp(3),qcvf(4,mxfan)

    real(eb) :: ppmdv(2,nr,ns), interior_rel_pressure(nr), fkw(mxslb,nwal,nr), cw(mxslb,nwal,nr), &
        rw(mxslb,nwal,nr), exterior_rel_pressure(nr), flw(mxslb,nwal,nr), epw(nwal,nr), twj(nnodes,nr,nwal), fopos(3,0:mxfire), &
        toxict(nr,2,ns), femr(0:mxfire), hlp(mxhvents), hvextt(mxext,2), &
        arext(mxext), hvelxt(mxext), ce(mxbranch), hvdvol(mxbranch), tbr(mxbranch), rohb(mxbranch), bflo(mxbranch), &
        hvp(mxnode), hvght(mxnode), dpz(mxnode,mxcon), hvflow(mxnode,mxcon), &
        qmax(mxfan), hmin(mxfan), hmax(mxfan), hvbco(mxfan,mxcoeff), eff_duct_diameter(mxduct), duct_area(mxduct),&
        duct_length(mxduct),hvconc(mxbranch,ns),qcvpp(4,nr,nr), hvexcn(mxext,ns,2),objpos(3,0:mxfires),fpos(3),hcrf(mxpts), &
        femp(0:mxfire),fems(0:mxfire),fqf(0:mxfire), fqfc(0:mxfire), fqlow(0:mxfire), fqupr(0:mxfire),fqdj(nr), &
        farea(0:mxfire)

    real(eb) :: cp, deltat, tracet(2,mxext)
    real(eb) :: gamma, hcomba, traces(2,mxext)
    real(eb) :: interior_abs_pressure, pofset, pref
    real(eb) :: relhum, rgas, stime, te
    real(eb) :: tgignt
    real(eb) :: tref

    logical :: activs(ns), mvcalc, objon(0:mxfires), heatfl, adiabatic_wall

    character(128) :: title

    type(room_type), target :: roominfo(nr)
   
    type(fire_type), target :: fireinfo(mxfire)
    
    integer :: nramps = 0
    type(ramp_type), target :: rampinfo(mxramps)
    
    type(visual_type), dimension (mxslice), target :: visual_info
    integer :: nvisualinfo = 0

    type(slice_type), allocatable, dimension(:), target :: sliceinfo  
    integer :: nsliceinfo
    type(iso_type), allocatable, dimension(:), target :: isoinfo  
    integer :: nisoinfo

     
end module cfast_main

! --------------------------- cfin -------------------------------------------

module cfin
    
    implicit none
    
    integer, parameter :: lbufln=1024
    character(lbufln) :: lbuf, cbuf
    
end module cfin

! --------------------------- cfio -------------------------------------------

module cfio

    use cfin    
    implicit none
    
    ! input/output data for readin, ...
      integer :: start, first, last, count, type, ix
      logical :: valid
      character(lbufln) :: inbuf
      real :: xi

end module cfio

! --------------------------- cshell -------------------------------------------

module cshell

    implicit none
    save

    ! rundat is today's date
    ! trace determines the type of output (print file) for mechanical ventilation - current or total
    logical :: nokbd=.false., initializeonly=.false.
    logical :: debugging=.false., trace=.false., validate=.false., netheatflux=.false.
    integer :: version, iofili=1, iofilo=6, outputformat=0, logerr=3
    integer, dimension(3) :: rundat
    character(128) :: thrmfile="thermal"
    character(60) :: nnfile=" ", datafile
    character(32) :: mpsdatc
    
end module cshell

! --------------------------- dervs -------------------------------------------

module dervs

    use precision_parameters
    use cparams    
    implicit none
    save

    logical :: produp
    real(eb), dimension(maxteq) :: pdold, pold
    real(eb) :: told, dt

end module dervs

! --------------------------- fltarget -------------------------------------------

module fltarget
    use precision_parameters
    use cparams, only: mxthrmplen, mxtarg
    use  cfast_types, only: target_type
    implicit none
    save
    
    ! variables for calculation of flux to a target

    integer, parameter :: pde = 1                                   ! plate targets (cartesian coordinates)
    integer, parameter :: cylpde = 2                                ! cylindrical targets (cylindrical coordinates)
    integer, parameter :: interior = 1
    integer, parameter :: exterior = 2

    real(eb), dimension(2) :: qtcflux, qtfflux, qtwflux, qtgflux    ! temporary variables for target flux calculation
    
    type (target_type), dimension(mxtarg), target :: targetinfo     ! structured target data
    
end module fltarget

! --------------------------- iofiles -------------------------------------------

module  iofiles

    use precision_parameters
    implicit none
    save
    
!File descriptors for cfast

    character(6), parameter :: heading="VERSN"
    character(64) :: project
    character(256) :: datapath, exepath, inputfile, outputfile, smvhead, smvdata, smvcsv, &
        ssflow, ssnormal, ssspecies, sswall, errorlogging, stopfile, solverini, &
        historyfile, queryfile, statusfile, kernelisrunning

! Work arrays for the csv input routines

    integer, parameter :: nrow=2000, ncol=200
    real(eb) :: rarray(nrow,ncol) 
    character(128) :: carray(nrow,ncol)

end module iofiles

! --------------------------- debug -------------------------------------------

module  debug

    use precision_parameters
    implicit none

    logical :: residprn, jacprn
    logical :: residfirst = .true.
    logical :: jacfirst = .true.
    logical :: nwline=.true.
    logical :: prnslab
    integer :: ioresid, iojac, ioslab
    real(eb) ::   dbtime
    character(256) :: residfile, jacfile, residcsv, jaccsv, slabcsv

end module debug

! --------------------------- objects1 -------------------------------------------

module objects1

    use cparams
    implicit none
    save

    logical, dimension(0:mxfires) :: objld
    character(64), dimension(0:mxfires) :: odbnam
    character(256), dimension(0:mxfires) :: objnin
    integer, dimension(0:mxfires) :: objpnt

end module objects1

! --------------------------- objects2 -------------------------------------------

module objects2

    use precision_parameters
    use cparams
    implicit none
    save

    logical, dimension(0:mxfires) :: objdef
    character(60), dimension(0:mxfires) :: omatl
    integer, dimension(mxfires) :: objlfm,objtyp,obtarg, objset
    
    real(eb), dimension(mxfires) :: obj_c, obj_h, obj_o, obj_n, obj_cl
    real(eb), dimension(3,0:mxfires) :: objcri, objort
    real(eb), dimension(0:mxfires) :: objmas, objgmw, objvt, objclen
    real(eb), dimension(mxpts,0:mxfires) :: objhc, omass, oarea, ohigh, oqdot ,oco, ohcr, ood, ooc
    real(eb), dimension(mxpts,ns,mxfires) :: omprodr
    real(eb), dimension(mxpts,mxfires) :: otime
    real(eb), dimension(2,0:mxfires) :: obcond
    real(eb) :: objmint, objphi, objhgas, objqarea, pnlds, dypdt, dxpdt, dybdt, dxbdt, dqdt

end module objects2

! --------------------------- opt -------------------------------------------

module opt

    use precision_parameters
    use cparams
    implicit none
    save
    
    integer, parameter :: mxdebug = 19
    integer, parameter :: mxopt = 21

    integer, parameter :: off = 0
    integer, parameter :: on = 1

    integer, parameter :: fccfm = 1
    integer, parameter :: fcfast = 2

    integer, parameter :: ffire = 1
    integer, parameter :: fhflow = 2
    integer, parameter :: fentrain = 3
    integer, parameter :: fvflow = 4
    integer, parameter :: fcjet = 5
    integer, parameter :: fdfire = 6
    integer, parameter :: fconvec = 7
    integer, parameter :: frad = 8
    integer, parameter :: fconduc = 9
    integer, parameter :: fdebug = 10
    integer, parameter :: fode=11
    integer, parameter :: fhcl=12
    integer, parameter :: fmvent=13
    integer, parameter :: fkeyeval=14
    integer, parameter :: fpsteady=15
    integer, parameter :: fhvloss=16
    integer, parameter :: fmodjac=17
    integer, parameter :: fpdassl=18
    integer, parameter :: foxygen=19
    integer, parameter :: fbtdtect=20
    integer, parameter :: fbtobj=21
 
    integer, parameter :: d_jac = 17
    integer, parameter :: d_cnt = 1
    integer, parameter :: d_prn = 2
    integer, parameter :: d_mass = 1
    integer, parameter :: d_hvac = 2
    integer, parameter :: d_hflw = 3
    integer, parameter :: d_vflw = 4
    integer, parameter :: d_mvnt = 5
    integer, parameter :: d_dpdt = 18
    integer, parameter :: d_diag = 19

    integer, parameter :: verysm = -9
    integer, parameter :: verybg = 9

    integer, dimension(mxopt) :: option = &
        ! fire, hflow, entrain, vflow, cjet
        (/   2,     1,       1,     1,    1,  &
        ! door-fire, convec, rad, conduct, debug
                  1,      1,   2,       1,     0,  &
        ! exact ode,  hcl, mflow, keyboard, type of initialization
                  1,    0,     1,        1,                      0,  &
        !  mv heat loss, mod jac, dassl debug, oxygen dassl solve, back track on dtect, back track on objects
                      0,       0,           0,                  0,                   0,                    0/)
!*** in above change default rad option from 2 to 4
!*** this causes absorption coefs to take on constant default values rather than computed from data
    integer, dimension(mxopt) :: d_debug = 0
    
    real(eb) :: cutjac, stptime, prttime, tottime, ovtime, tovtime
    
    integer :: iprtalg = 0, jacchk = 0
    integer :: numjac = 0, numstep = 0, numresd = 0, numitr = 0, totjac = 0, totstep = 0, totresd = 0, totitr = 0, total_steps = 0
 
    integer(2), dimension(mxdebug,2,nr) :: dbugsw
    

      end module opt

! --------------------------- params -------------------------------------------

module params

    use precision_parameters
    use cparams
    implicit none
    save

!   these are temporary work arrays

!   ex... are the settings for the external ambient
!   qfr,... are the heat balance calculations for calculate_residuals and conductive_flux. it is now indexed by
!    fire rather than by compartment
!   the variables ht.. and hf.. are for vertical flow
!   the volume fractions volfru and volfrl are calculated by calculate_residuals at the beginning of a time step
!   hvfrac is the fraction that a mv duct is in the upper or lower layer

    logical :: allowed(ns), exset
    integer :: izhvmapi(mxnode), izhvmape(mxnode), izhvie(mxnode), izhvsys(mxnode), izhvbsys(mxbranch), nhvpvar, nhvtvar, nhvsys

    real(eb) :: qfc(2,nr), o2n2(ns), &
        volfru(nr), volfrl(nr), hvfrac(2,mxext), exterior_abs_pressure, &
        chv(mxbranch), dhvprsys(mxnode,ns), hvtm(mxhvsys), hvmfsys(mxhvsys),hvdara(mxbranch), ductcv

end module params

! --------------------------- smkview -------------------------------------------

module smkview_data

    use precision_parameters
    use cparams
    implicit none
    save

    integer :: smkunit, spltunit, flocal(mxfire+1)
    character(60) :: smkgeom, smkplot, smkplottrunc
    logical :: remapfiresdone
    real(eb), dimension(mxfire+1) :: fqlocal, fzlocal, fxlocal, fylocal, fhlocal
  
end module smkview_data

! --------------------------- solver_parameters -------------------------------------------

module solver_parameters

    use precision_parameters
    use cparams
    implicit none
    save
    
    real(eb), dimension(nt) :: pinit
    real(eb), dimension(1) :: rpar2
    integer, dimension(3) :: ipar2
    real(eb) :: aptol = 1.0e-6_eb        ! absolute pressure tolerance
    real(eb) :: rptol = 1.0e-6_eb        ! relative pressure tolerance
    real(eb) :: atol = 1.0e-5_eb         ! absolute other tolerance
    real(eb) :: rtol = 1.0e-5_eb         ! relative other tolerance
    real(eb) :: awtol = 1.0e-2_eb        ! absolute wall tolerance
    real(eb) :: rwtol = 1.0e-2_eb        ! relative wall tolerance
    real(eb) :: algtol = 1.0e-8_eb       ! initialization tolerance
    real(eb) :: ahvptol = 1.0e-6_eb      ! absolute HVAC pressure tolerance
    real(eb) :: rhvptol = 1.0e-6_eb      ! relative HVAC pressure tolerance
    real(eb) :: ahvttol = 1.0e-5_eb      ! absolute HVAC temperature tolerance
    real(eb) :: rhvttol = 1.0e-5_eb      ! relative HVAC temperature tolerance
    
    real(eb) :: stpmax = 1.0_eb        ! maximum solver time step, if negative, then solver will decide
    real(eb) :: dasslfts = 0.005_eb    ! first time step for DASSL

end module solver_parameters

! --------------------------- thermp -------------------------------------------

module thermp

    use precision_parameters
    use cparams
    implicit none
    save
    
    real(eb), dimension(mxslb,mxthrmp) :: lfkw, lcw, lrw, lflw
    real(eb), dimension(mxthrmp) :: lepw

    integer maxct, numthrm
    integer, dimension(mxthrmp) :: lnslb
    character(mxthrmplen), dimension(mxthrmp) :: nlist

    end module thermp
    
! --------------------------- fires -------------------------------------------
    
module fires

end module fires

! --------------------------- vents -------------------------------------------

module vents

    use precision_parameters
    use cparams, only: nr, mxhvent, mxvvent, mxext
    use cfast_types, only: vent_type
    implicit none
    save
    
    integer, dimension(mxhvent,2) :: ivvent
    integer :: n_hvents, n_vvents
    
    real(eb), dimension(nr,mxhvent) :: zzventdist
    real(eb), dimension(2,mxhvent) :: vss, vsa, vas, vaa, vsas, vasa
    
    type (vent_type), dimension(mxhvent), target :: hventinfo
    type (vent_type), dimension(mxvvent), target :: vventinfo
    type (vent_type), dimension(mxext), target :: mventinfo
    
end module vents

! --------------------------- vent_slab -------------------------------------------

module vent_slab
    
    use precision_parameters
    use cparams, only: mxfslab
    implicit none
    save
    
    real(eb), dimension(mxfslab) :: yvelev, dpv1m2
    integer, dimension(mxfslab) ::  dirs12
    integer :: nvelev, ioutf
      
end module vent_slab

! --------------------------- wdervs -------------------------------------------

module wdervs

    implicit none
    save
    
    integer :: jacn1, jacn2, jacn3, jacdim
      
end module wdervs

! --------------------------- wnodes -------------------------------------------

module wnodes

    use precision_parameters
    use cparams
    implicit none
    save
    
    integer :: nwpts = 30                                   ! number of wall nodes
    integer :: iwbound = 3                                  !boundary condition type (1=constant temperature, 2=insulated 3=flux)
     ! computed values for boundary thickness, initially fractions for inner, middle and outer wall slab
    real(eb), dimension(3) :: wsplit = (/0.50_eb, 0.17_eb, 0.33_eb/)  
    
    integer nwalls, nfurn
    real(eb), dimension (nr,4) :: wlength
    real(eb), dimension (nnodes,nr,4) :: walldx
    real(eb), dimension(mxpts) :: furn_time, furn_temp
    real(eb) :: qfurnout
      
end module wnodes