module model_setting
    integer, public :: npes, mpicom
    integer, public :: timelen, levlen, latlen, lonlen
    real, public, allocatable :: ssh(:,:), shf(:,:)
    real, public, allocatable :: sst(:,:), mld(:,:), ssf(:,:)
    real, public, allocatable :: lev(:), lat(:), lon(:)

    public arrays_are_the_same !check if two arrays with same dimensions are the same

    contains
    logical function arrays_are_the_same(global, global_back)
        implicit none
        real, intent(in) :: global(latlen, lonlen)
        real, intent(in) :: global_back(latlen, lonlen)
        integer :: i, j, m

        arrays_are_the_same = .true.
            do j = 1, latlen
            do m = 1, lonlen
                if (global(j,m) .ne. global_back(j,m)) then
                    arrays_are_the_same = .false.
                end if
            end do
            end do
        return
    end function

    subroutine read_input_data(masterproc)
        use mpi
        implicit none
        include "netcdf.inc"
!#include <mpif.h>
        logical, intent(in) :: masterproc
        character*1024 :: input_data_dir, input_file_name
        character*1024 :: input_file_dir_name
        integer :: ncid_input, ret
        integer :: sshid, shfid, tsid, mldid, ssfid
        integer :: levid
        integer :: latid
        integer :: lonid
        integer :: decomp_size, local_grid_cell_index

        input_data_dir  = './'
        input_file_name = "licom.059106-0591071.nc"
        input_file_dir_name = input_data_dir//input_file_name

        levlen = 30
        latlen = 196
        lonlen = 360
        timelen = 1
        allocate(lev(levlen), lat(latlen), lon(lonlen))
        if (masterproc) then
            ret = nf_open (input_file_name, nf_nowrite, ncid_input)
    
            ret = nf_inq_varid (ncid_input, "z0", sshid) !sea surface height
            ret = nf_inq_varid (ncid_input, "net1", shfid)!net surface heat flux
            ret = nf_inq_varid (ncid_input, "sst", tsid)!3d temperature
            ret = nf_inq_varid (ncid_input, "mld", mldid)!mixed layer depth
            ret = nf_inq_varid (ncid_input, "net2", ssfid)!net surface salt flux
            ret = nf_inq_varid (ncid_input, "lev", levid)
            ret = nf_inq_varid (ncid_input, "lon", lonid)
            ret = nf_inq_varid (ncid_input, "lat", latid)
    
            !allocate(ssht(timelen, latlen, lonlen), shft(timelen, latlen, lonlen), mldt(timelen, latlen, lonlen), ssft(timelen, latlen, lonlen))
            !allocate(lev(levlen), lat(latlen), lon(lonlen))
            !allocate(tst(timelen,levlen, latlen, lonlen), sst(latlen, lonlen))
            !allocate(ssh(latlen, lonlen), shf(latlen, lonlen), mld(latlen, lonlen))
            !allocate(ssf(latlen, lonlen))
            allocate(sst(latlen, lonlen))
            allocate(ssh(latlen, lonlen), shf(latlen, lonlen))
            allocate(mld(latlen, lonlen))

            ret = nf_get_var_real (ncid_input, sshid, ssh)
            ret = nf_get_var_real (ncid_input, shfid, shf)
            ret = nf_get_var_real (ncid_input, tsid, sst)
            ret = nf_get_var_real (ncid_input, mldid, mld)

            ret = nf_get_var_real (ncid_input, levid, lev)
            ret = nf_get_var_real (ncid_input, latid, lat)
            ret = nf_get_var_real (ncid_input, lonid, lon)
        else
            allocate(ssh(1,1), shf(1,1), mld(1,1), ssf(1,1))
            allocate(sst(1,1))
!           allocate(ssh(latlen,lonlen), shf(latlen,lonlen), mld(latlen,lonlen), ssf(latlen,lonlen))
!           allocate(lev(1), lat(1), lon(1))
!           allocate(sst(latlen,lonlen))
        end if 

    end subroutine read_input_data

    subroutine scatter_field(global_field, local_field, local_grid_cell_indexes, decomp_size, masterproc, ier)
        use mpi
        implicit none
        
        integer, intent(in) :: decomp_size, ier
        integer, intent(in) :: local_grid_cell_indexes(decomp_size,npes)
        logical, intent(in) :: masterproc
        real, intent(in) :: global_field(latlen, lonlen)
        real, intent(out) :: local_field(decomp_size)

        !------------local variables---------------------------
        real gfield(latlen*lonlen)
        real lfield(decomp_size)
        real gfield_back(latlen*lonlen)
        real global_field_back(latlen,lonlen)
        integer :: p, i, j, m
        integer :: displs(1:npes) !scatter displacements
        integer :: sndcnts(1:npes) !scatter send counts
        integer :: recvcnt !scatter receive count

        logical :: check
        !number of grid points scattered to eache process
        
        sndcnts(:) = decomp_size
        displs(1) = 0
        do p=2, npes
            displs(p) = displs(p-1)+decomp_size
        end do
        recvcnt = decomp_size

        !copy field into global data structure
        if (masterproc) then
            j = 1
            do p=1,npes
                do i=1,decomp_size
                    m = ceiling((local_grid_cell_indexes(i,p)-0.5)/(latlen/1.0))
                    gfield(j) = global_field(local_grid_cell_indexes(i,p)-latlen*(m-1),m)
                    j = j+1
                end do
            end do
        end if

        !scatter to other processes
        call mpi_scatterv(gfield, sndcnts, displs, mpi_real4, &
            lfield, recvcnt, mpi_real4, 0, mpicom, ier)
        !copy into local data structure
        do i=1,decomp_size
            local_field(i) = lfield(i)
        end do
    end subroutine scatter_field

end module

program licom
    use model_setting
    use mpi
    use coupling_atm_model_mod
    
    implicit none
    
    integer :: ier, mpitask_id
    logical :: masterproc
    integer :: i, j
    real(4), allocatable :: ssh_l(:), shf_l(:)
    real(4), allocatable :: sst_l(:), mld_l(:)
    real(4), allocatable :: sstm(:),shfm(:)
    real(4), allocatable :: sshm(:),mldm(:)
    integer :: time_step, time_length
    integer :: decomp_size
    integer, allocatable :: local_grid_cell_index(:,:)

    integer :: import_interface_id, export_interface_id

    mpicom = CCPL_NULL_COMM
    call mpi_init(ier)
    call register_licom_component(mpicom)
    call mpi_comm_rank(mpicom, mpitask_id, ier)
    call mpi_comm_size(mpicom, npes, ier)

    if (mpitask_id == 0) then
        masterproc = .true.
    else
        masterproc = .false.
    end if

    call read_input_data(masterproc)

    call mpi_bcast(lev, levlen, mpi_integer, 0, mpicom, ier)
    call mpi_bcast(lat, latlen, mpi_integer, 0, mpicom, ier)
    call mpi_bcast(lon, lonlen, mpi_integer, 0, mpicom, ier)


    !---setting up decomposition for licom----------------------
    decomp_size = latlen*lonlen/npes
    allocate(sst_l(decomp_size),shf_l(decomp_size))
    allocate(ssh_l(decomp_size),mld_l(decomp_size))

    if ((latlen*lonlen-decomp_size*npes) .ne. 0) then
        print *, "ERROR : grid cells cannot be equally decomposed to number of porcs"
    end if
    allocate(local_grid_cell_index(decomp_size,npes))
    do j = 1, npes
    do i = 1, decomp_size
        !local_grid_cell_index(i,j) = i+(j-1)*decomp_size
        local_grid_cell_index(i,j) = j+(i-1)*npes
    end do
    end do

    call scatter_field(sst, sst_l, local_grid_cell_index, decomp_size, masterproc, ier)
    call scatter_field(shf, shf_l, local_grid_cell_index, decomp_size, masterproc, ier)
    call scatter_field(ssh, ssh_l, local_grid_cell_index, decomp_size, masterproc, ier)
    call scatter_field(mld, mld_l, local_grid_cell_index, decomp_size, masterproc, ier)

    call register_grids_decomps(latlen, lonlen, lat, lon, decomp_size, mpitask_id, npes, local_grid_cell_index)

    !------------Entering time loop-----------------------------
    time_length = 3*3600     !in seconds
    time_step = 1800         !in seconds

    !assign variables for model processing
    allocate(sstm(decomp_size),shfm(decomp_size))
    allocate(sshm(decomp_size),mldm(decomp_size))

    call register_component_coupling_configuration(decomp_size, sstm, shfm, sshm, mldm, time_step, licom_comp_id, "licom", import_interface_id, export_interface_id)

    do i=1,time_length/time_step
        sstm = sst_l
        shfm = shf_l
        sshm = ssh_l
        mldm = mld_l
    end do

    deallocate(sstm,shfm,sshm,mldm)
    deallocate(sst_l,shf_l,ssh_l,mld_l)
    deallocate(local_grid_cell_index)
    deallocate(ssh,sst,shf,mld,lev,lat,lon)

    call mpi_finalize(ier)
    print*,"licom running completed"

end program
