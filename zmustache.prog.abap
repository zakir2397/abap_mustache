*/--------------------------------------------------------------------------------\
*| This file is part of ABAP MUSTACHE                                             |
*|                                                                                |
*| The MIT License (MIT)                                                          |
*|                                                                                |
*| Copyright (c) 2018 Alexander Tsybulsky (atsybulsky@sbcg.com.ua)                |
*|                                                                                |
*| Permission is hereby granted, free of charge, to any person obtaining a copy   |
*| of this software and associated documentation files (the "Software"), to deal  |
*| in the Software without restriction, including without limitation the rights   |
*| to use, copy, modify, merge, publish, distribute, sublicense, and/or sell      |
*| copies of the Software, and to permit persons to whom the Software is          |
*| furnished to do so, subject to the following conditions:                       |
*|                                                                                |
*| The above copyright notice and this permission notice shall be included in all |
*| copies or substantial portions of the Software.                                |
*|                                                                                |
*| THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR     |
*| IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,       |
*| FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE    |
*| AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER         |
*| LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  |
*| OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  |
*| SOFTWARE.                                                                      |
*\--------------------------------------------------------------------------------/
*| project homepage: https://github.com/sbcgua/abap_mustache                      |
*\--------------------------------------------------------------------------------/

**********************************************************************
* UTILS
**********************************************************************

CLASS lcl_mustache_utils DEFINITION FINAL.

  PUBLIC SECTION.

    CLASS-METHODS split_string
      IMPORTING iv_text       TYPE string
                iv_sep        TYPE clike OPTIONAL
      RETURNING VALUE(rt_tab) TYPE string_table.

    CLASS-METHODS join_strings
      IMPORTING it_tab         TYPE string_table
                iv_sep         TYPE clike OPTIONAL
      RETURNING VALUE(rv_text) TYPE string.

    class-methods CHECK_VERSION_FITS
      importing
        !I_REQUIRED_VERSION type STRING
        !I_CURRENT_VERSION type STRING
      returning
        value(R_FITS) type ABAP_BOOL .

ENDCLASS. "lcl_mustache_utils

CLASS lcl_mustache_utils IMPLEMENTATION.

  METHOD split_string.

    IF iv_sep IS NOT INITIAL.
      SPLIT iv_text AT iv_sep INTO TABLE rt_tab.
    ELSE.
      FIND FIRST OCCURRENCE OF cl_abap_char_utilities=>cr_lf IN iv_text.
      IF sy-subrc = 0.
        SPLIT iv_text AT cl_abap_char_utilities=>cr_lf INTO TABLE rt_tab.
      ELSE.
        SPLIT iv_text AT cl_abap_char_utilities=>newline INTO TABLE rt_tab.
      ENDIF.
    ENDIF.

  ENDMETHOD.  " split_string.

  METHOD join_strings.

    DATA lv_sep TYPE string.

    IF iv_sep IS NOT SUPPLIED.
      lv_sep = cl_abap_char_utilities=>newline.
    ELSE.
      lv_sep = iv_sep.
    ENDIF.

    CONCATENATE LINES OF it_tab INTO rv_text SEPARATED BY lv_sep.

  ENDMETHOD. "join_strings

  method check_version_fits.

    types:
      begin of ty_version,
        major type numc4,
        minor type numc4,
        patch type numc4,
      end of ty_version.

    data ls_cur_ver type ty_version.
    data ls_req_ver type ty_version.
    data lv_buf type string.

    lv_buf = i_current_version.
    shift lv_buf left deleting leading 'v'.
    split lv_buf at '.' into ls_cur_ver-major ls_cur_ver-minor ls_cur_ver-patch.

    lv_buf = i_required_version.
    shift lv_buf left deleting leading 'v'.
    split lv_buf at '.' into ls_req_ver-major ls_req_ver-minor ls_req_ver-patch.

    if ls_req_ver-major <= ls_cur_ver-major.
      if ls_req_ver-minor <= ls_cur_ver-minor.
        if ls_req_ver-patch <= ls_cur_ver-patch.
          r_fits = abap_true.
        endif.
      endif.
    endif.

  endmethod.

ENDCLASS. "lcl_mustache_utils

**********************************************************************
* MUSTACHE LOGIC
**********************************************************************

*----------------------------------------------------------------------*
*       CLASS lcl_mustache DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_mustache_render DEFINITION DEFERRED.
CLASS lcl_mustache DEFINITION FINAL
  FRIENDS lcl_mustache_render.

  PUBLIC SECTION.

    CONSTANTS C_VERSION TYPE string VALUE '1.0.0'. " Package version

    INTERFACES zif_mustache.
    ALIASES:
      render FOR zif_mustache~render,
      render_tt FOR zif_mustache~render_tt,
      add_partial FOR zif_mustache~add_partial,
      get_partials FOR zif_mustache~get_partials,
      get_tokens FOR zif_mustache~get_tokens.

    " TYPES ************************************************************

    TYPES:
      BEGIN OF ty_context,
        tokens     TYPE zif_mustache=>ty_token_tt,
        partials   TYPE zif_mustache=>ty_partial_tt,
        x_format   TYPE zif_mustache=>ty_x_format,
        part_depth TYPE i,
      END OF ty_context.

    " METHODS **********************************************************

    CLASS-METHODS create
      IMPORTING
        iv_template TYPE string       OPTIONAL
        it_template TYPE string_table OPTIONAL
        iv_x_format TYPE zif_mustache=>ty_x_format  DEFAULT cl_abap_format=>e_html_text
      PREFERRED
        PARAMETER iv_template
      RETURNING
        VALUE(ro_instance) TYPE REF TO lcl_mustache
      RAISING
        zcx_mustache_error.

    METHODS constructor
      IMPORTING
        iv_template TYPE string       OPTIONAL
        it_template TYPE string_table OPTIONAL
        iv_x_format TYPE zif_mustache=>ty_x_format  DEFAULT cl_abap_format=>e_html_text
      PREFERRED PARAMETER iv_template
      RAISING
        zcx_mustache_error.

    class-methods CHECK_VERSION_FITS
      importing
        !I_REQUIRED_VERSION type STRING
      returning
        value(R_FITS) type ABAP_BOOL .

  PRIVATE SECTION.
    DATA mt_tokens   TYPE zif_mustache=>ty_token_tt.
    DATA mt_partials TYPE zif_mustache=>ty_partial_tt.
    DATA mv_x_format TYPE zif_mustache=>ty_x_format.

ENDCLASS. "lcl_mustache


*----------------------------------------------------------------------*
*       CLASS lcl_mustache_parser
*----------------------------------------------------------------------*
CLASS lcl_mustache_parser DEFINITION FINAL.
  PUBLIC SECTION.

    CLASS-METHODS parse_template
      IMPORTING
        iv_template      TYPE string       OPTIONAL
        it_template      TYPE string_table OPTIONAL
      PREFERRED PARAMETER iv_template
      RETURNING
        VALUE(rt_tokens) TYPE zif_mustache=>ty_token_tt
      RAISING
        zcx_mustache_error.

    CLASS-METHODS tokenize
      IMPORTING
        iv_template       TYPE string
      EXPORTING
        et_tokens         TYPE zif_mustache=>ty_token_tt
        ev_lonely_section TYPE abap_bool
      RAISING
        zcx_mustache_error.

    CLASS-METHODS parse_tag
      IMPORTING
        iv_chunk        TYPE string
      RETURNING
        VALUE(rv_token) TYPE zif_mustache=>ty_token
      RAISING
        zcx_mustache_error.

    CLASS-METHODS build_token_structure
      CHANGING
        ct_tokens TYPE zif_mustache=>ty_token_tt
      RAISING
        zcx_mustache_error.

ENDCLASS.

CLASS lcl_mustache_parser IMPLEMENTATION.

  METHOD parse_template.

    DATA: lt_strings        TYPE string_table,
          lv_lonely_section TYPE abap_bool,
          lv_first_line     TYPE abap_bool VALUE abap_true,
          ls_newline_token  LIKE LINE OF rt_tokens,
          lt_token_portion  LIKE rt_tokens.

    FIELD-SYMBOLS <line> LIKE LINE OF lt_strings.

    ASSERT NOT ( iv_template IS NOT INITIAL AND lines( it_template ) > 0 ).

    IF lines( it_template ) > 0.
      LOOP AT it_template ASSIGNING <line>.
        APPEND LINES OF lcl_mustache_utils=>split_string( <line> ) TO lt_strings.
      ENDLOOP.
    ELSE. " iv_template, which can also be empty then
      lt_strings = lcl_mustache_utils=>split_string( iv_template ).
    ENDIF.

    ls_newline_token-type    = zif_mustache=>c_token_type-static.
    ls_newline_token-content = cl_abap_char_utilities=>newline.

    LOOP AT lt_strings ASSIGNING <line>.
      IF lv_first_line = abap_false AND lv_lonely_section = abap_false.
        " Don't insert before first line and after lonely sections
        APPEND ls_newline_token TO rt_tokens.
      ENDIF.

      tokenize(
        EXPORTING iv_template       = <line>
        IMPORTING et_tokens         = lt_token_portion
                  ev_lonely_section = lv_lonely_section ).
      APPEND LINES OF lt_token_portion TO rt_tokens.

      CLEAR lv_first_line.
    ENDLOOP.

    build_token_structure( changing ct_tokens = rt_tokens ).

  ENDMETHOD.  " parse_template.

  METHOD tokenize.

    DATA:
          lv_otag  TYPE string VALUE '{{',
          lv_ctag  TYPE string VALUE '}}',
          lv_intag TYPE abap_bool,
          lv_cur   TYPE i,
          lv_len   TYPE i,
          lv_off   TYPE i.

    FIELD-SYMBOLS <token> LIKE LINE OF et_tokens.

    CLEAR et_tokens.
    ev_lonely_section = abap_true.
    lv_len            = strlen( iv_template ).

    DO.

      IF lv_intag = abap_true.  " Inside of a tag
        FIND FIRST OCCURRENCE OF lv_ctag
          IN SECTION OFFSET lv_cur OF iv_template
          MATCH OFFSET lv_off.

        IF sy-subrc > 0. " Closing tag not found !
          zcx_mustache_error=>raise(
            msg = 'Closing }} not found'
            rc  = 'CTNF' ).
        ENDIF.

        IF lv_ctag = '}}' AND lv_len - lv_off > 2 AND iv_template+lv_off(3) = '}}}'.
          lv_off = lv_off + 1. " Crutch for {{{x}}} (to find internal closing '}')
        ENDIF.

        APPEND INITIAL LINE TO et_tokens ASSIGNING <token>.
        <token> = parse_tag( substring( val = iv_template
                                        off = lv_cur
                                        len = lv_off - lv_cur ) ).

        IF NOT ( <token>-type = zif_mustache=>c_token_type-section OR <token>-type = zif_mustache=>c_token_type-section_end ).
          " Any tag other than section makes it not lonely
          CLEAR ev_lonely_section.
        ENDIF.

        IF <token>-type = zif_mustache=>c_token_type-delimiter. " Change open/close tags
          SPLIT <token>-content AT ` ` INTO lv_otag lv_ctag.
        ENDIF.

        lv_intag = abap_false.
        lv_cur   = lv_off + strlen( lv_ctag ).

      ELSE.                     " In static text part
        FIND FIRST OCCURRENCE OF lv_otag
          IN SECTION OFFSET lv_cur OF iv_template
          MATCH OFFSET lv_off.

        IF sy-subrc > 0. " No more tags found
          lv_off = strlen( iv_template ).
        ELSE. " Open tag found
          lv_intag = abap_true.
        ENDIF.

        IF lv_off > lv_cur. " Append unempty static token
          APPEND INITIAL LINE TO et_tokens ASSIGNING <token>.
          <token>-type    = zif_mustache=>c_token_type-static.
          <token>-content = substring( val = iv_template
                                       off = lv_cur
                                       len = lv_off - lv_cur ).

          IF ev_lonely_section = abap_true AND <token>-content CN ` `.
            " Non space static section resets makes section not lonely
            CLEAR ev_lonely_section.
          ENDIF.
        ENDIF.

        IF lv_intag = abap_true. " Tag was found
          lv_cur   = lv_off + strlen( lv_otag ).
        ELSE.
          EXIT. " End of template - exit loop
        ENDIF.
      ENDIF.

    ENDDO.

    IF ev_lonely_section = abap_true.
      " Delete all static content at lonely section line
      DELETE et_tokens WHERE type = zif_mustache=>c_token_type-static.
    ENDIF.

  ENDMETHOD.  " tokenize.

  METHOD parse_tag.

    DATA: lv_sigil TYPE string,
          lv_tail  TYPE c,
          lv_cnt   TYPE i,
          lv_param TYPE string.

    lv_param = iv_chunk.

    IF strlen( lv_param ) = 0.
      zcx_mustache_error=>raise(
        msg = 'Empty tag'
        rc  = 'ET' ).
    ENDIF.

    IF lv_param(1) CA '#^/=!>&{'. " Get tag type
      lv_sigil = iv_chunk(1).
      SHIFT lv_param BY 1 PLACES.
    ENDIF.

    IF strlen( lv_param ) = 0.
      zcx_mustache_error=>raise(
        msg = 'Empty tag'
        rc  = 'ET' ).
    ENDIF.

    IF lv_sigil CA '={'. " Check closing part of tag type
      lv_tail = substring( val = lv_param  off = strlen( lv_param ) - 1  len = 1 ).
      IF lv_sigil = '=' AND lv_tail <> '='.
        zcx_mustache_error=>raise(
          msg = 'Missing closing ='
          rc  = 'MC=' ).
      ENDIF.
      IF lv_sigil = '{' AND lv_tail <> '}'.
        zcx_mustache_error=>raise(
          msg = 'Missing closing }'
          rc  = 'MC}' ).
      ENDIF.
      lv_param = substring( val = lv_param  len = strlen( lv_param ) - 1 ).
    ENDIF.

    " Trip spaces
    SHIFT lv_param RIGHT DELETING TRAILING space.
    SHIFT lv_param LEFT DELETING LEADING space.

    IF strlen( lv_param ) = 0.
      zcx_mustache_error=>raise(
        msg = 'Empty tag'
        rc  = 'ET' ).
    ENDIF.

    CASE lv_sigil.
      WHEN ''.
        rv_token-type = zif_mustache=>c_token_type-etag.
      WHEN '&' OR '{'.
        rv_token-type = zif_mustache=>c_token_type-utag.
      WHEN '#'.
        rv_token-type = zif_mustache=>c_token_type-section.
        rv_token-cond = zif_mustache=>c_section_condition-if.
      WHEN '^'.
        rv_token-type = zif_mustache=>c_token_type-section.
        rv_token-cond = zif_mustache=>c_section_condition-ifnot.
      WHEN '/'.
        rv_token-type = zif_mustache=>c_token_type-section_end.
      WHEN '='.
        rv_token-type = zif_mustache=>c_token_type-delimiter.
        CONDENSE lv_param. " Remove unnecessary internal spaces too
        FIND ALL OCCURRENCES OF ` ` IN lv_param MATCH COUNT lv_cnt.
        IF lv_cnt <> 1. " Must contain one separating space
          zcx_mustache_error=>raise(
            msg = |Change of delimiters failed: '{ lv_param }'|
            rc  = 'CDF' ).
        ENDIF.
      WHEN '!'. " Comment
        rv_token-type = zif_mustache=>c_token_type-comment.
      WHEN '>'.
        rv_token-type = zif_mustache=>c_token_type-partial.
      WHEN OTHERS.
        ASSERT 0 = 1. " Cannot reach, programming error
    ENDCASE.

    rv_token-content = lv_param.

  ENDMETHOD.  " parse_tag.

  METHOD build_token_structure.

    DATA:
          lv_idx    TYPE i,
          lv_level  TYPE i VALUE 1,
          lt_stack  TYPE string_table.

    FIELD-SYMBOLS: <token>        LIKE LINE OF ct_tokens,
                   <section_name> LIKE LINE OF lt_stack.

    " Validate, build levels, remove comments
    LOOP AT ct_tokens ASSIGNING <token>.
      <token>-level = lv_level.
      lv_idx        = sy-tabix.

      CASE <token>-type.
        WHEN zif_mustache=>c_token_type-comment.
          DELETE ct_tokens INDEX lv_idx. " Ignore comments

        WHEN zif_mustache=>c_token_type-delimiter.
          DELETE ct_tokens INDEX lv_idx. " They served their purpose in tokenize

        WHEN zif_mustache=>c_token_type-section.
          lv_level = lv_level + 1.
          APPEND <token>-content TO lt_stack.

        WHEN zif_mustache=>c_token_type-section_end.
          lv_level = lv_level - 1.
          IF lv_level < 1.
            zcx_mustache_error=>raise(
              msg = |Closing of non-opened section: { <token>-content }|
              rc  = 'CNOS' ).
          ENDIF.

          READ TABLE lt_stack INDEX lines( lt_stack ) ASSIGNING <section_name>.
          IF <section_name> <> <token>-content.
            zcx_mustache_error=>raise(
              msg = |Closing section mismatch: { <section_name> } ({ lv_level })|
              rc  = 'CSM' ).
          ENDIF.

          DELETE lt_stack INDEX lines( lt_stack ). " Remove, not needed anymore
          DELETE ct_tokens INDEX lv_idx. " No further need for section close tag

        WHEN OTHERS.
          ASSERT 1 = 1. " Do nothing
      ENDCASE.
    ENDLOOP.

    IF lv_level > 1.
      READ TABLE lt_stack INDEX lines( lt_stack ) ASSIGNING <section_name>.
      zcx_mustache_error=>raise(
        msg = |Section not closed: { <section_name> } ({ lv_level })|
        rc  = 'SNC' ).
    ENDIF.

  ENDMETHOD.  " build_token_structure.

ENDCLASS.


*----------------------------------------------------------------------*
*       CLASS lcl_mustache_render
*----------------------------------------------------------------------*

CLASS lcl_mustache_render DEFINITION FINAL.
  PUBLIC SECTION.

    CONSTANTS:
      " Max depth of partials recursion, feel free to change for your needs
      C_MAX_PARTIALS_DEPTH TYPE i VALUE 10.

    CONSTANTS:
      BEGIN OF c_data_type,
        elem  TYPE char10 VALUE 'IFPCDNTg',
        struc TYPE char2  VALUE 'uv',
        table TYPE char1  VALUE 'h',
        oref  TYPE char1  VALUE 'r',
      END OF c_data_type.

    CLASS-METHODS render_section
      IMPORTING
        is_statics    TYPE lcl_mustache=>ty_context
        i_data        TYPE any
        it_data_stack TYPE zif_mustache=>ty_ref_tt     OPTIONAL
        iv_start_idx  TYPE i             DEFAULT 1
        iv_path       TYPE string        DEFAULT '/'
      CHANGING
        ct_lines      TYPE string_table
      RAISING
        zcx_mustache_error.

    CLASS-METHODS render_loop
      IMPORTING
        is_statics    TYPE lcl_mustache=>ty_context
        it_data_stack TYPE zif_mustache=>ty_ref_tt
        iv_start_idx  TYPE i
        iv_path       TYPE string
      CHANGING
        ct_lines      TYPE string_table
      RAISING
        zcx_mustache_error.

    CLASS-METHODS find_value
      IMPORTING
        iv_name       TYPE string
        it_data_stack TYPE zif_mustache=>ty_ref_tt
      RETURNING
        VALUE(rv_val) TYPE string
      RAISING
        zcx_mustache_error.

    CLASS-METHODS find_walker
      IMPORTING
        iv_name       TYPE string
        it_data_stack TYPE zif_mustache=>ty_ref_tt
        iv_level      TYPE i
      RETURNING
        VALUE(rv_ref) TYPE REF TO data
      RAISING
        zcx_mustache_error.

    CLASS-METHODS eval_condition
      IMPORTING
        iv_var           TYPE any
        iv_cond          TYPE zif_mustache=>ty_token-cond
      RETURNING
        VALUE(rv_result) TYPE abap_bool
      RAISING
        zcx_mustache_error.

    CLASS-METHODS render_oref
      IMPORTING
        io_obj      TYPE REF TO object
        iv_tag_name TYPE string OPTIONAL
      RETURNING
        VALUE(rv_val) TYPE string
      RAISING
        zcx_mustache_error.

    CLASS-METHODS class_constructor.

  PRIVATE SECTION.

    CLASS-DATA: c_ty_struc_tt_absolute_name TYPE abap_abstypename.

ENDCLASS.

CLASS lcl_mustache_render IMPLEMENTATION.

  METHOD class_constructor.
    DATA lt_dummy TYPE zif_mustache=>ty_struc_tt.
    c_ty_struc_tt_absolute_name = cl_abap_typedescr=>describe_by_data( lt_dummy )->absolute_name.
  ENDMETHOD. "class_constructor

  METHOD render_section.

    DATA: lr            TYPE REF TO data,
          lv_type       TYPE c,
          lv_unitab     TYPE abap_bool,
          lt_data_stack LIKE it_data_stack.

    FIELD-SYMBOLS: <table>   TYPE ANY TABLE,
                   <tabline> TYPE any.

    DESCRIBE FIELD i_data TYPE lv_type.

    IF lv_type CA c_data_type-table
       AND cl_abap_typedescr=>describe_by_data( i_data )->absolute_name
           = c_ty_struc_tt_absolute_name.
      lv_unitab = abap_true.
    ENDIF.

    " Input is a structure - one time render
    IF lv_type CA c_data_type-struc
       OR lv_type CA c_data_type-elem
       OR lv_unitab = abap_true.

      " Update context
      lt_data_stack = it_data_stack.
      GET REFERENCE OF i_data INTO lr.
      APPEND lr TO lt_data_stack.

      render_loop(
        EXPORTING
          is_statics    = is_statics
          it_data_stack = lt_data_stack
          iv_start_idx  = iv_start_idx
          iv_path       = iv_path
        CHANGING
          ct_lines      = ct_lines ).

    " Input is a table - iterate
    ELSEIF lv_type CA c_data_type-table.

      ASSIGN i_data TO <table>.
      LOOP AT <table> ASSIGNING <tabline>.
        render_section(
          EXPORTING
            is_statics    = is_statics
            it_data_stack = it_data_stack
            iv_start_idx  = iv_start_idx
            i_data        = <tabline>
            iv_path       = iv_path
        CHANGING
          ct_lines        = ct_lines ).
      ENDLOOP.

    ELSE.
      zcx_mustache_error=>raise(
        msg = |Cannot render section { iv_path }, wrong data item type|
        rc  = 'CRWD' ).
    ENDIF.

  ENDMETHOD.  " render_section.

  METHOD render_loop.

    DATA:
          lr         TYPE REF TO data,
          ls_statics TYPE lcl_mustache=>ty_context,
          lv_level   TYPE i,
          lv_idx     TYPE i,
          lv_val     TYPE string.

    FIELD-SYMBOLS: <field>   TYPE any,
                   <partial> LIKE LINE OF is_statics-partials,
                   <token>   LIKE LINE OF is_statics-tokens.

    " Rendering loop
    LOOP AT is_statics-tokens ASSIGNING <token> FROM iv_start_idx.
      lv_idx = sy-tabix.

      ASSERT <token>-level > 0. " Protection from programming errors
      IF lv_level = 0.
        lv_level = <token>-level. " Copy from first record
      ENDIF.

      IF <token>-level < lv_level. " Reached end of section
        EXIT.
      ENDIF.

      IF <token>-level > lv_level. " Processed by deeper sections
        CONTINUE.
      ENDIF.

      CASE <token>-type.
        WHEN zif_mustache=>c_token_type-static.                     " Static particle
          APPEND <token>-content TO ct_lines.

        WHEN zif_mustache=>c_token_type-etag OR zif_mustache=>c_token_type-utag.  " Single tag
          lv_val  = find_value( iv_name = <token>-content  it_data_stack = it_data_stack ).
          IF <token>-type = zif_mustache=>c_token_type-etag AND is_statics-x_format IS NOT INITIAL.
            lv_val = escape( val = lv_val format = is_statics-x_format ).
          ENDIF.
          APPEND lv_val TO ct_lines.

        WHEN zif_mustache=>c_token_type-section.
          lr = find_walker( iv_name       = <token>-content
                            it_data_stack = it_data_stack
                            iv_level      = lines( it_data_stack ) ). " Start from deepest level
          ASSIGN lr->* TO <field>.

          IF abap_true = eval_condition( iv_var = <field> iv_cond = <token>-cond ).
            render_section(
              EXPORTING
                is_statics    = is_statics
                it_data_stack = it_data_stack
                iv_start_idx  = lv_idx + 1
                i_data        = <field>
                iv_path       = iv_path && <token>-content && '/'
              CHANGING
                ct_lines      = ct_lines ).
          ENDIF.

        WHEN zif_mustache=>c_token_type-partial.
          IF is_statics-part_depth = C_MAX_PARTIALS_DEPTH.
            zcx_mustache_error=>raise(
              msg = |Max partials depth reached ({ C_MAX_PARTIALS_DEPTH })|
              rc  = 'MPD' ).
          ENDIF.

          READ TABLE is_statics-partials ASSIGNING <partial> WITH KEY name = <token>-content.
          IF sy-subrc > 0.
            zcx_mustache_error=>raise(
              msg = |Partial '{ <token>-content }' not found|
              rc  = 'PNF' ).
          ENDIF.

          ls_statics-tokens      = <partial>-obj->get_tokens( ).
          ls_statics-partials    = <partial>-obj->get_partials( ).
          ls_statics-x_format    = is_statics-x_format.
          ls_statics-part_depth  = is_statics-part_depth + 1.

          render_loop(
            EXPORTING
              is_statics    = ls_statics
              it_data_stack = it_data_stack
              iv_start_idx  = 1 " Start from start
              iv_path       = iv_path && '>' && <token>-content && '/'
            CHANGING
              ct_lines      = ct_lines ).

        WHEN OTHERS.
          ASSERT 0 = 1. " Cannot reach, programming error
      ENDCASE.

    ENDLOOP.

  ENDMETHOD.  " render_loop.

  METHOD find_value.

    DATA: lr      TYPE REF TO data,
          lv_type TYPE c.

    FIELD-SYMBOLS: <field> TYPE any.

    lr = find_walker( iv_name       = iv_name
                      it_data_stack = it_data_stack
                      iv_level      = lines( it_data_stack ) ). " Start from deepest level

    ASSIGN lr->* TO <field>.
    DESCRIBE FIELD <field> TYPE lv_type.

    IF lv_type CA c_data_type-elem. " Element data type
      rv_val = <field>.
    ELSEIF lv_type CA c_data_type-oref. " Object or interface instance
      rv_val = render_oref( iv_tag_name = iv_name io_obj = <field> ).
    ELSE.
      zcx_mustache_error=>raise(
        msg = |Cannot convert { iv_name } to string|
        rc  = 'CCTS' ).
    ENDIF.


  ENDMETHOD.  " find_value.

  METHOD find_walker.

    DATA:
          lo_type       TYPE REF TO cl_abap_typedescr,
          lv_type       TYPE c,
          lv_found      TYPE abap_bool,
          lv_name_upper TYPE string,
          lr            TYPE REF TO data.

    FIELD-SYMBOLS: <field> TYPE any,
                   <struc> TYPE any,
                   <rec>   TYPE zif_mustache=>ty_struc,
                   <table> TYPE ANY TABLE.

    lv_name_upper = to_upper( iv_name ).

    READ TABLE it_data_stack INTO lr INDEX iv_level.
    ASSIGN lr->* TO <field>.
    DESCRIBE FIELD <field> TYPE lv_type.
    UNASSIGN <field>.

    IF lv_type CA c_data_type-elem. " Element data type.
      " Assuming value can happen just at the lowest level
      " Then just ignore but don't throw an error
      " it will be found by name in higher context levels

      " Except special item @tabline
      " It assumes iterating on table of elements
      IF lv_name_upper = '@TABLINE'.
        rv_ref = lr.
        lv_found = abap_true.
      ENDIF.

    ELSEIF lv_type CA c_data_type-struc.   " Structure
      ASSIGN lr->* TO <struc>.
      ASSIGN COMPONENT lv_name_upper OF STRUCTURE <struc> TO <field>.
      IF sy-subrc = 0. " Found
        GET REFERENCE OF <field> INTO rv_ref.
        lv_found = abap_true.
      ENDIF.

    ELSEIF lv_type CA c_data_type-table.    " Table
      lo_type = cl_abap_typedescr=>describe_by_data_ref( lr ).
      IF lo_type->absolute_name <> c_ty_struc_tt_absolute_name.
        zcx_mustache_error=>raise(
          msg = |Cannot find values in tables other than of ty_struc_tt type|
          rc  = 'WTT' ).
      ENDIF.

      ASSIGN lr->* TO <table>.
      LOOP AT <table> ASSIGNING <rec>.
        IF to_upper( <rec>-name ) = lv_name_upper.
          lv_found = abap_true.
          IF <rec>-dref IS NOT INITIAL.
            rv_ref = <rec>-dref.
          ELSEIF <rec>-oref IS NOT INITIAL.
            GET REFERENCE OF <rec>-oref INTO rv_ref.
          ELSE.
            GET REFERENCE OF <rec>-val INTO rv_ref.
          ENDIF.
          EXIT.
        ENDIF.
      ENDLOOP.

    ELSE.                     " Anything else is unsupported
      zcx_mustache_error=>raise(
        msg = |Can find values in structures or ty_struc_tt tables only|
        rc  = 'WVT' ).
    ENDIF.

    IF lv_found <> abap_true.
      IF iv_level > 1.
        " Search upper levels
        rv_ref = find_walker( iv_name       = iv_name
                              it_data_stack = it_data_stack
                              iv_level      = iv_level - 1 ).
      ELSE.
        zcx_mustache_error=>raise(
          msg = |Field '{ iv_name }' not found in supplied data|
          rc  = 'FNF' ).
      ENDIF.
    ENDIF.

  ENDMETHOD. "find_walker

  METHOD eval_condition.

    CASE iv_cond.
      WHEN zif_mustache=>c_section_condition-if.
        IF iv_var IS NOT INITIAL.
          rv_result = abap_true.
        ENDIF.

      WHEN zif_mustache=>c_section_condition-ifnot.
        IF iv_var IS INITIAL.
          rv_result = abap_true.
        ENDIF.

      WHEN OTHERS.
        zcx_mustache_error=>raise(
          msg = |Unknown condition '{ iv_cond }'|
          rc  = 'UC' ).
    ENDCASE.

  ENDMETHOD. "eval_condition

  METHOD render_oref.

    DATA lo_type TYPE REF TO cl_abap_objectdescr.
    DATA ls_meth LIKE LINE OF lo_type->methods.
    DATA ls_param LIKE LINE OF ls_meth-parameters.
    DATA lv_meth_found TYPE abap_bool.
    DATA lv_if TYPE abap_methname.
    DATA lv_if_meth TYPE abap_methname.

    lo_type ?= cl_abap_objectdescr=>describe_by_object_ref( io_obj ).

    LOOP AT lo_type->methods INTO ls_meth.
      SPLIT ls_meth-name AT '~' INTO lv_if lv_if_meth.
      IF lv_if = 'RENDER' AND lv_if_meth IS INITIAL OR lv_if_meth = 'RENDER'.
        lv_meth_found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_meth_found = abap_false.
      zcx_mustache_error=>raise(
        msg = |Object does not have render method for tag '{ iv_tag_name }'|
        rc  = 'ODHR' ).
    ENDIF.

    READ TABLE ls_meth-parameters TRANSPORTING NO FIELDS
      WITH KEY parm_kind = 'I' is_optional = ''.
    IF sy-subrc IS INITIAL.
      zcx_mustache_error=>raise(
        msg = |Object render() has mandatory params for tag '{ iv_tag_name }'|
        rc  = 'ORMP' ).
    ENDIF.

    READ TABLE ls_meth-parameters INTO ls_param
      WITH KEY parm_kind = cl_abap_objectdescr=>returning type_kind = cl_abap_typedescr=>typekind_string.
    IF sy-subrc IS NOT INITIAL.
      zcx_mustache_error=>raise(
        msg = |Object render() does not return string for tag '{ iv_tag_name }'|
        rc  = 'ORRS' ).
    ENDIF.

    DATA lt_ptab TYPE abap_parmbind_tab.
    DATA ls_ptab LIKE LINE OF lt_ptab.

    ls_ptab-name = ls_param-name.
    ls_ptab-kind = cl_abap_objectdescr=>receiving.
    GET REFERENCE OF rv_val INTO ls_ptab-value.
    INSERT ls_ptab INTO TABLE lt_ptab.

    CALL METHOD io_obj->(ls_meth-name)
      PARAMETER-TABLE lt_ptab.

  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
*       CLASS lcl_mustache IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_mustache IMPLEMENTATION.

  METHOD create.
    CREATE OBJECT ro_instance
      EXPORTING
        iv_template = iv_template
        it_template = it_template
        iv_x_format = iv_x_format.
  ENDMETHOD. " create.

  METHOD constructor.
    mv_x_format = iv_x_format.
    mt_tokens   = lcl_mustache_parser=>parse_template(
      iv_template = iv_template
      it_template = it_template ).
  ENDMETHOD.  " constructor.

  METHOD render_tt.

    rt_tab = lcl_mustache_utils=>split_string(
      iv_sep  = cl_abap_char_utilities=>newline
      iv_text = render( i_data ) ).

  ENDMETHOD.  " render_tt.

  METHOD render.

    DATA: lt_temp    TYPE string_table,
          ls_statics TYPE ty_context.

    ls_statics-tokens   = mt_tokens.
    ls_statics-partials = mt_partials.
    ls_statics-x_format = mv_x_format.

    lcl_mustache_render=>render_section(
      EXPORTING
        is_statics  = ls_statics
        i_data      = i_data
      CHANGING
        ct_lines = lt_temp ).

    rv_text = lcl_mustache_utils=>join_strings( it_tab = lt_temp iv_sep = '' ).

  ENDMETHOD.  " render.

  METHOD add_partial.

    FIELD-SYMBOLS <p> LIKE LINE OF mt_partials.

    IF io_obj IS NOT BOUND.
      zcx_mustache_error=>raise(
        msg = 'Partial object is not bound'
        rc  = 'PONB' ).
    ENDIF.

    READ TABLE mt_partials TRANSPORTING NO FIELDS WITH KEY name = iv_name.
    IF sy-subrc = 0.
      zcx_mustache_error=>raise(
        msg = |Duplicate partial '{ iv_name }'|
        rc  = 'DP' ).
    ENDIF.

    APPEND INITIAL LINE TO mt_partials ASSIGNING <p>.
    <p>-name = iv_name.
    <p>-obj  = io_obj.

  ENDMETHOD.  " add_partial

  METHOD get_partials.
    rt_partials = mt_partials.
  ENDMETHOD.

  METHOD get_tokens.
    rt_tokens = mt_tokens.
  ENDMETHOD.

  method CHECK_VERSION_FITS.

    r_fits = lcl_mustache_utils=>check_version_fits(
      i_current_version  = zif_mustache=>version
      i_required_version = i_required_version ).

  endmethod.

ENDCLASS. "lcl_mustache
