!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief Lumps all possible extended system variables into one
!>    type for easy access and passing
!> \par History
!>      Teodoro Laino - 09.2007 - University of Zurich
!>        Cleaned the typo.. no need to have an extended
!>        type. Thermostat and Barostat type have been created
!> \author CJM
! **************************************************************************************************
MODULE extended_system_types
   USE bibliography,                    ONLY: Nose1984a,&
                                              Nose1984b,&
                                              cite_reference
   USE input_constants,                 ONLY: do_thermo_no_communication
   USE input_section_types,             ONLY: section_vals_type,&
                                              section_vals_val_get
   USE kinds,                           ONLY: dp
#include "./base/base_uses.f90"

   IMPLICIT NONE
   PRIVATE

   PUBLIC :: lnhc_dealloc, &
             lnhc_init, &
             lnhc_parameters_type, &
             map_info_type, &
             create_map_info_type, &
             release_map_info_type, &
             npt_info_type

   LOGICAL, PARAMETER, PUBLIC :: debug_isotropic_limit = .FALSE.
   LOGICAL, PARAMETER, PUBLIC :: debug_uniaxial_limit = .FALSE.

! **************************************************************************************************
   TYPE npt_info_type
      REAL(KIND=dp) :: eps = -1.0_dp
      REAL(KIND=dp) :: v = -1.0_dp
      REAL(KIND=dp) :: f = -1.0_dp
      REAL(KIND=dp) :: mass = -1.0_dp
   END TYPE npt_info_type

! **************************************************************************************************
   TYPE nhc_info_type
      INTEGER        :: degrees_of_freedom = -1
      REAL(KIND=dp) :: eta = -1.0_dp
      REAL(KIND=dp) :: v = -1.0_dp
      REAL(KIND=dp) :: f = -1.0_dp
      REAL(KIND=dp) :: nkt = -1.0_dp
      REAL(KIND=dp) :: mass = -1.0_dp
   END TYPE nhc_info_type

! **************************************************************************************************
   TYPE point_info_type
      REAL(KIND=dp), POINTER :: point => NULL()
   END TYPE point_info_type

! **************************************************************************************************
   TYPE map_info_type
      INTEGER                                         :: dis_type = -1
      INTEGER, POINTER, DIMENSION(:)                  :: index => NULL(), map_index => NULL()
      REAL(KIND=dp), POINTER, DIMENSION(:)           :: v_scale => NULL()
      REAL(KIND=dp), POINTER, DIMENSION(:)           :: s_kin => NULL()
      TYPE(point_info_type), POINTER, DIMENSION(:, :) :: p_scale => NULL()
      TYPE(point_info_type), POINTER, DIMENSION(:, :) :: p_kin => NULL()
   END TYPE map_info_type

! **************************************************************************************************
   TYPE lnhc_parameters_type
      INTEGER                                 :: nyosh = -1, nc = -1, nhc_len = -1
      INTEGER                                 :: glob_num_nhc = -1, loc_num_nhc = -1, region = -1
      REAL(KIND=dp)                           :: tau_nhc = -1.0_dp, dt_fact = -1.0_dp
      REAL(KIND=dp), POINTER                  :: dt_yosh(:) => NULL()
      TYPE(nhc_info_type), POINTER            :: nvt(:, :) => NULL()
      TYPE(map_info_type), POINTER            :: map_info => NULL()
   END TYPE lnhc_parameters_type

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'extended_system_types'

CONTAINS

! **************************************************************************************************
!> \brief Initialize type for Nose-Hoover thermostat
!> \param lnhc ...
!> \param section ...
! **************************************************************************************************
   SUBROUTINE lnhc_init(lnhc, section)
      TYPE(lnhc_parameters_type), POINTER                :: lnhc
      TYPE(section_vals_type), POINTER                   :: section

      NULLIFY (lnhc%dt_yosh)
      NULLIFY (lnhc%nvt)
      NULLIFY (lnhc%map_info)
      lnhc%loc_num_nhc = 0
      lnhc%glob_num_nhc = 0
      lnhc%dt_fact = 1.0_dp
      CALL cite_reference(Nose1984a)
      CALL cite_reference(Nose1984b)
      CALL section_vals_val_get(section, "LENGTH", i_val=lnhc%nhc_len)
      CALL section_vals_val_get(section, "YOSHIDA", i_val=lnhc%nyosh)
      CALL section_vals_val_get(section, "TIMECON", r_val=lnhc%tau_nhc)
      CALL section_vals_val_get(section, "MTS", i_val=lnhc%nc)
      CALL create_map_info_type(lnhc%map_info)

   END SUBROUTINE lnhc_init

! **************************************************************************************************
!> \brief create the map_info type
!> \param map_info ...
! **************************************************************************************************
   SUBROUTINE create_map_info_type(map_info)
      TYPE(map_info_type), POINTER                       :: map_info

      ALLOCATE (map_info)
      NULLIFY (map_info%index, map_info%map_index)
      NULLIFY (map_info%v_scale)
      NULLIFY (map_info%p_scale)
      NULLIFY (map_info%s_kin)
      NULLIFY (map_info%p_kin)
      map_info%dis_type = do_thermo_no_communication

   END SUBROUTINE create_map_info_type

! **************************************************************************************************
!> \brief release the map_info type
!> \param map_info ...
! **************************************************************************************************
   SUBROUTINE release_map_info_type(map_info)
      TYPE(map_info_type), POINTER                       :: map_info

      IF (ASSOCIATED(map_info)) THEN
         IF (ASSOCIATED(map_info%p_kin)) THEN
            DEALLOCATE (map_info%p_kin)
         END IF
         IF (ASSOCIATED(map_info%p_scale)) THEN
            DEALLOCATE (map_info%p_scale)
         END IF
         IF (ASSOCIATED(map_info%v_scale)) THEN
            DEALLOCATE (map_info%v_scale)
         END IF
         IF (ASSOCIATED(map_info%s_kin)) THEN
            DEALLOCATE (map_info%s_kin)
         END IF
         IF (ASSOCIATED(map_info%index)) THEN
            DEALLOCATE (map_info%index)
         END IF
         IF (ASSOCIATED(map_info%map_index)) THEN
            DEALLOCATE (map_info%map_index)
         END IF

         DEALLOCATE (map_info)
      END IF

   END SUBROUTINE release_map_info_type

! **************************************************************************************************
!> \brief Deallocate type for Nose-Hoover thermostat
!> \param lnhc ...
! **************************************************************************************************
   SUBROUTINE lnhc_dealloc(lnhc)
      TYPE(lnhc_parameters_type), POINTER                :: lnhc

      IF (ASSOCIATED(lnhc)) THEN
         IF (ASSOCIATED(lnhc%dt_yosh)) THEN
            DEALLOCATE (lnhc%dt_yosh)
         END IF
         IF (ASSOCIATED(lnhc%nvt)) THEN
            DEALLOCATE (lnhc%nvt)
         END IF
         CALL release_map_info_type(lnhc%map_info)
         DEALLOCATE (lnhc)
      END IF

   END SUBROUTINE lnhc_dealloc

END MODULE extended_system_types
