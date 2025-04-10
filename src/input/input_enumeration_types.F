!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright 2000-2025 CP2K developers group <https://cp2k.org>                                   !
!                                                                                                  !
!   SPDX-License-Identifier: GPL-2.0-or-later                                                      !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief represents an enumeration, i.e. a mapping between integers and strings
!> \par History
!>      08.2004 created [fawzi]
!> \author fawzi
! **************************************************************************************************
MODULE input_enumeration_types

   USE cp_log_handling,                 ONLY: cp_to_string
   USE kinds,                           ONLY: default_string_length
   USE string_utilities,                ONLY: a2s,&
                                              uppercase
#include "../base/base_uses.f90"

   IMPLICIT NONE
   PRIVATE

   LOGICAL, PRIVATE, PARAMETER :: debug_this_module = .TRUE.
   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'input_enumeration_types'

   PUBLIC :: enumeration_type
   PUBLIC :: enum_create, enum_retain, enum_release, enum_i2c, enum_c2i

! **************************************************************************************************
!> \brief represents an enumaration, i.e. a mapping between strings and numbers
!> \param ref_count reference count
!> \param c_vals string values
!> \param i_vals integer values
!> \param strict if integer values not in the list should be accepted
!> \author fawzi
! **************************************************************************************************
   TYPE char_array
      CHARACTER, DIMENSION(:), POINTER :: chars => Null()
   END TYPE char_array

   TYPE enumeration_type
      INTEGER :: ref_count = 0
      CHARACTER(len=default_string_length), DIMENSION(:), POINTER :: c_vals => NULL()
      TYPE(char_array), DIMENSION(:), POINTER :: desc => Null()
      INTEGER, DIMENSION(:), POINTER :: i_vals => NULL()
      LOGICAL :: strict = .FALSE.
   END TYPE enumeration_type

CONTAINS

! **************************************************************************************************
!> \brief creates an enumeration
!> \param enum the enumeration to be created
!> \param c_vals string values
!> \param i_vals integer values
!> \param desc ...
!> \param strict if integer values not in the list should be accepted,
!>        defaults defaults to true
!> \author fawzi
! **************************************************************************************************
   SUBROUTINE enum_create(enum, c_vals, i_vals, desc, strict)
      TYPE(enumeration_type), POINTER                    :: enum
      CHARACTER(len=*), DIMENSION(:), INTENT(in)         :: c_vals
      INTEGER, DIMENSION(:), INTENT(in)                  :: i_vals
      CHARACTER(len=*), DIMENSION(:), INTENT(in), &
         OPTIONAL                                        :: desc
      LOGICAL, INTENT(in), OPTIONAL                      :: strict

      INTEGER                                            :: i, j, n

      CPASSERT(.NOT. ASSOCIATED(enum))
      CPASSERT(SIZE(c_vals) == SIZE(i_vals))
      ALLOCATE (enum)
      enum%ref_count = 1
      ALLOCATE (enum%c_vals(SIZE(c_vals)))
      DO i = 1, SIZE(enum%c_vals)
         CPASSERT(LEN_TRIM(c_vals(i)) > 0)
         enum%c_vals(i) = c_vals(i)
         CALL uppercase(enum%c_vals(i))
      END DO
      ALLOCATE (enum%i_vals(SIZE(i_vals)))
      enum%i_vals = i_vals
      enum%strict = .TRUE.
      IF (PRESENT(strict)) enum%strict = strict
      ALLOCATE (enum%desc(SIZE(c_vals)))
      IF (PRESENT(desc)) THEN
         CPASSERT(SIZE(enum%desc) == SIZE(desc))
         DO i = 1, SIZE(enum%desc)
            n = LEN_TRIM(desc(i))
            ALLOCATE (enum%desc(i)%chars(n))
            DO j = 1, n
               enum%desc(i)%chars(j) = desc(i) (j:j)
            END DO
         END DO
      ELSE
         DO i = 1, SIZE(enum%desc)
            ALLOCATE (enum%desc(i)%chars(1))
            enum%desc(i)%chars(1:1) = ' '
         END DO
      END IF
   END SUBROUTINE enum_create

! **************************************************************************************************
!> \brief retains the given enumeration
!> \param enum the obect to retain
!> \author fawzi
! **************************************************************************************************
   SUBROUTINE enum_retain(enum)
      TYPE(enumeration_type), POINTER                    :: enum

      CPASSERT(ASSOCIATED(enum))
      CPASSERT(enum%ref_count > 0)
      enum%ref_count = enum%ref_count + 1
   END SUBROUTINE enum_retain

! **************************************************************************************************
!> \brief releases the given enumeration
!> \param enum the obect to release
!> \author fawzi
! **************************************************************************************************
   SUBROUTINE enum_release(enum)
      TYPE(enumeration_type), POINTER                    :: enum

      INTEGER                                            :: i

      IF (ASSOCIATED(enum)) THEN
         CPASSERT(enum%ref_count > 0)
         enum%ref_count = enum%ref_count - 1
         IF (enum%ref_count == 0) THEN
            DEALLOCATE (enum%c_vals)
            DEALLOCATE (enum%i_vals)
            DO i = 1, SIZE(enum%desc)
               DEALLOCATE (enum%desc(i)%chars)
            END DO
            DEALLOCATE (enum%desc)
            DEALLOCATE (enum)
         END IF
      END IF
      NULLIFY (enum)
   END SUBROUTINE enum_release

! **************************************************************************************************
!> \brief maps an integer to a string
!> \param enum the enumeration to use for the mapping
!> \param i the value to map
!> \return ...
!> \author fawzi
! **************************************************************************************************
   FUNCTION enum_i2c(enum, i) RESULT(res)
      TYPE(enumeration_type), POINTER                    :: enum
      INTEGER, INTENT(in)                                :: i
      CHARACTER(len=default_string_length)               :: res

      INTEGER                                            :: j
      LOGICAL                                            :: found

      CPASSERT(ASSOCIATED(enum))
      CPASSERT(enum%ref_count > 0)
      res = " "
      found = .FALSE.
      DO j = 1, SIZE(enum%i_vals)
         IF (enum%i_vals(j) == i) THEN
            res = enum%c_vals(j)
            found = .TRUE.
            EXIT
         END IF
      END DO
      IF (.NOT. found) THEN
         IF (enum%strict) THEN
            DO j = 1, SIZE(enum%desc)
               PRINT *, TRIM(a2s(enum%desc(j)%chars))
               PRINT *, TRIM(enum%c_vals(j))
            END DO
            PRINT *, enum%i_vals
         END IF
         IF (enum%strict) &
            CPABORT("invalid value for enumeration:"//cp_to_string(i))
         res = ADJUSTL(cp_to_string(i))
      END IF
   END FUNCTION enum_i2c

! **************************************************************************************************
!> \brief maps a string to an integer
!> \param enum the enumeration to use for the mapping
!> \param c the value to map
!> \return ...
!> \author fawzi
! **************************************************************************************************
   FUNCTION enum_c2i(enum, c) RESULT(res)
      TYPE(enumeration_type), POINTER                    :: enum
      CHARACTER(len=*), INTENT(in)                       :: c
      INTEGER                                            :: res

      CHARACTER(len=default_string_length)               :: upc
      INTEGER                                            :: iostat, j
      LOGICAL                                            :: found

      CPASSERT(ASSOCIATED(enum))
      CPASSERT(enum%ref_count > 0)
      upc = TRIM(ADJUSTL(c)) !MK Ignore leading and trailing blanks
      CALL uppercase(upc)
      found = .FALSE.
      DO j = 1, SIZE(enum%c_vals)
         IF (enum%c_vals(j) == upc) THEN
            res = enum%i_vals(j)
            found = .TRUE.
            EXIT
         END IF
      END DO

      IF (.NOT. found) THEN
         IF (enum%strict) &
            CPABORT("invalid value for enumeration:"//TRIM(c))
         READ (c, "(i10)", iostat=iostat) res
         IF (iostat /= 0) &
            CPABORT("invalid value for enumeration2:"//TRIM(c))
      END IF
   END FUNCTION enum_c2i

END MODULE input_enumeration_types
