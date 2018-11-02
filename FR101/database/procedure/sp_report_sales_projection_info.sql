USE [msv_acopco]
GO
/****** Object:  StoredProcedure [dbo].[sp_report_sales_projection_info]    Script Date: 9/19/2018 4:36:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
 * Function to report Service Call metrics
 */
ALTER PROCEDURE [dbo].[sp_report_sales_projection_info]
    @i_session_id [sessionid], 
    @i_user_id [userid], 
    @i_client_id [uddt_client_id], 
    @i_locale_id [uddt_locale_id], 
    @i_country_code [uddt_country_code],
    @o_retrieve_status [uddt_varchar_5] OUTPUT
AS
BEGIN
   
	set @o_retrieve_status = ''
	
	declare @p_summary_by varchar(50), @p_series_by varchar(50), @p_month varchar(3),
			@p_report_info varchar(100),  @p_employee_id varchar(30),
			@p_organogram_level_no varchar(1), @p_organogram_level_code nvarchar(15),
			@p_company_location varchar(10), @p_asset_status nvarchar(30),
			@p_equipment_category nvarchar(30), @p_equipment_type nvarchar(60),
			@p_mapped_to_employee varchar(30), @p_detail_view varchar(5),
			@p_user_group_id nvarchar(20),
			@p_user_home_company_location varchar(10)
	

	select @p_employee_id = paramval from #input_params where paramname = 'employee_id'
	
	select @p_user_home_company_location = location_code
	from employee
	where company_id = @i_client_id
	  and country_code = @i_country_code
	  and employee_id = @p_employee_id

	create table #report_equipment_categories_applicable
	(
	  equipment_category nvarchar(30) not null
	)

	create table #report_equipment_types_applicable
	(
		equipment_type nvarchar(60) not null
	)

	insert #report_equipment_categories_applicable
	select category_code_value from category_type_link
	where company_id = @i_client_id
	  and country_code = @i_country_code
	  and link_type = 'EC'

	insert #report_equipment_types_applicable
	select type_code_value from category_type_link
	where company_id = @i_client_id
	  and country_code = @i_country_code
	  and link_type = 'EC'
	
	if @p_employee_id  != '%'
	begin

		select @p_user_group_id = user_group_id
		from users
		where company_id = @i_client_id
		  and country_code	= @i_country_code
		  and employee_id		= @p_employee_id

		if @p_user_group_id	in ('DLRCORDASQ','SCOORD-DLR')
		begin
			set @p_mapped_to_employee	= NULL
			set @p_company_location		= NULL
			select  @p_organogram_level_no   = a.organogram_level_no,
					@p_organogram_level_code = a.organogram_level_code
					
			from employee a
			where a.company_id	= @i_client_id
				and a.country_code	= @i_country_code
				and a.employee_id	= @p_employee_id
		end
		else if @p_user_group_id in ('SM-OEM','RM','RSM','RPM')
		begin
			select @p_company_location = location_code 
				from employee
					where company_id = @i_client_id
						and country_code	= @i_country_code
						and employee_id		= @p_employee_id
			set @p_mapped_to_employee		= NULL
			set @p_organogram_level_no		= NULL
			set	@p_organogram_level_code	= NULL
			
			if @p_user_group_id = 'RPM'
			begin

				delete #report_equipment_categories_applicable
				where equipment_category not in 
				(select distinct equipment_category
				from dealer_mapping_to_employee a
				where a.company_id = @i_client_id
				  and a.country_code = @i_country_code
				  and a.mapping_purpose_code = 'RPMDLRPRODMAPPING'
				  and employee_id = @p_employee_id)

				  delete #report_equipment_types_applicable
				where equipment_type not in 
				(select distinct equipment_type
				from dealer_mapping_to_employee a
				where a.company_id = @i_client_id
				  and a.country_code = @i_country_code
				  and a.mapping_purpose_code = 'RPMDLRPRODMAPPING'
				  and employee_id = @p_employee_id)
			end

		end
		else if @p_user_group_id in ('OEM_SENGG')
		begin
			set @p_mapped_to_employee		= @p_employee_id
			set @p_organogram_level_no		= NULL
			set	@p_organogram_level_code	= NULL
			set @p_company_location			= NULL
		end
		else
		begin
			set @p_mapped_to_employee		= NULL
			set @p_organogram_level_no		= NULL
			set	@p_organogram_level_code	= NULL
			set @p_company_location			= NULL
		end
	end

	select @p_summary_by = paramval from #input_params where paramname = 'summary_by'
	select @p_series_by = paramval from #input_params where paramname = 'series_by'
	select @p_report_info = paramval from #input_params where paramname = 'report_info'
	select @p_organogram_level_no = paramval from #input_params where paramname = 'org_lvl_no'
	select @p_organogram_level_code = paramval from #input_params where paramname = 'org_lvl_code'
	select @p_company_location = paramval from #input_params where paramname = 'company_location'
	select @p_asset_status = paramval from #input_params where paramname = 'asset_status'
	select @p_equipment_category = paramval from #input_params where paramname = 'equipment_category'
	select @p_equipment_type = paramval from #input_params where paramname = 'equipment_type'
	select @p_detail_view = paramval from #input_params where paramname = 'detail_view'
	select @p_month = paramval from #input_params where paramname = 'month'
	
	
	if @p_asset_status = 'In-Warranty'
	begin
		set @p_asset_status = 1
	end
	if @p_asset_status = 'Out of Warranty'
	begin
		set @p_asset_status = 0
	end

	select @p_month = (
		case(@p_month) 
			when 'Jan' then 1 
			when 'Feb' then 2 
			when 'Mar' then 3 
			when 'Apr' then 4 
			when 'May' then 5 
			when 'Jun' then 6 
			when 'Jul' then 7 
			when 'Aug' then 8 
			when 'Sep' then 9 
			when 'Oct' then 10 
			when 'Nov' then 11
			when 'Dec' then 12
		end
	)
	
	if @p_report_info = 'sales_projection_count'
	begin
		create table #sales_projection_count (
			call_ref_no nvarchar(30),
			asset_id nvarchar(30),
			call_status varchar(30),
			asset_status nvarchar(30),
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_count (
			call_ref_no,
			asset_id,
			call_status, 
			asset_status,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.call_ref_no,
			a.asset_id,
			( case(a.call_status)
				when 'O' then 'Not Progressed'
				when 'A' then 'Not Progressed'
				when 'QG' then 'Not Progressed'
				when 'I' then 'Not Progressed'
				else 'Quoted'
			end	),
			a.asset_in_warranty_ind,
			a.equipment_id,
			b.equipment_type,
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category in ('PE','EQ')
			and a.equipment_id != 'ZZZ'
			and a.equipment_id = b.equipment_id
			and a.call_status not in ('CO','WC','OD','CC')
			and isnull(a.company_location_code, '') = 
				(case @p_company_location
				when 'HOME' then @p_user_home_company_location 
				when null then a.company_location_code
				else @p_company_location
				end) 
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)

			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = '4'
					
		if @p_detail_view = 'true'
		begin
  			select '' as o_report_info,
				'{' +
					'"call_ref_no":"' + call_ref_no + '",' +
					'"asset_id":"' + asset_id + '",' +
					'"asset_status":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"equipment_id":"' + equipment_id + '",' +
					'"call_status":"' + call_status + '",' +
					'"equipment_type":"' + equipment_type + '",' +
					'"org_lvl_code":"' + org_lvl_code + '",' +
					'"comp_loc":"' + company_location_code + '"' +
				'}' as o_report_info_json
			from #sales_projection_count
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
		end
		else if @p_summary_by = 'company_location'	
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + company_location_code + '",' +
					'"summary_name":"' + company_location_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by company_location_code
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by org_lvl_code
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by asset_status
		end
		else if @p_summary_by = 'equipment_type'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by equipment_type
		end
		else if @p_summary_by = 'call_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + call_status + '",' +
					'"summary_name":"' + call_status + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by call_status
		end
	end

	/* For split of  Lead and Oppertunity */

	else if @p_report_info = 'sales_projection_count_lead'
	begin
		create table #sales_projection_count_lead (
			call_ref_no nvarchar(30),
			asset_id nvarchar(30),
			call_status varchar(30),
			asset_status bit,
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_count_lead (
			call_ref_no,
			asset_id,
			call_status, 
			asset_status,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select 
			a.call_ref_no,
			a.asset_id,
			a.call_status,
			a.asset_in_warranty_ind,
			a.equipment_id,
			isnull(b.equipment_type,'ZZZ'),
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date			
		from call_register a
		left outer join equipment b
		on a.equipment_id = b.equipment_id
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.call_category in ('PE')
			and a.call_status in ('O','A','I','QG')
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = 4
			and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
		
		if @p_detail_view = 'true'
		begin
  			select '' as o_report_info,
				'{' +
					'"call_ref_no":"' + call_ref_no + '",' +
					'"asset_id":"' + asset_id + '",' +
					'"call_status":"' + call_status + '",' +
					'"asset_status":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"equipment_id":"' + equipment_id + '",' +
					'"equipment_type":"' + equipment_type + '",' +
					'"comp_loc":"' + company_location_code + '",' +
					'"org_lvl_code":"' + org_lvl_code + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
		end			
		else if @p_summary_by = 'company_location'	
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + company_location_code + '",' +
					'"summary_name":"' + company_location_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by company_location_code		
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by org_lvl_code
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by asset_status
		end
		else if @p_summary_by = 'month_wise'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + case(datepart(month, creation_date_time))
							when 1 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jan' 
							when 2 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Feb' 
							when 3 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Mar' 
							when 4 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Apr' 
							when 5 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'May' 
							when 6 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jun' 
							when 7 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jul' 
							when 8 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Aug' 
							when 9 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Sep' 
							when 10 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Oct' 
							when 11 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Nov' 
							when 12 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Dec' 
						end + '",' +
					'"summary_name":"' + case(datepart(month, creation_date_time))
							when 1 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jan'
							when 2 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Feb'
							when 3 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Mar'
							when 4 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Apr'
							when 5 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'May'
							when 6 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jun'
							when 7 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jul'
							when 8 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Aug'
							when 9 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Sep'
							when 10 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Oct'
							when 11 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Nov'
							when 12 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Dec'
						end + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by datepart(month, creation_date_time), datepart(year, creation_date_time)
			order by datepart(year, creation_date_time) asc
		end
		else if @p_summary_by = 'equipment_type'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by equipment_type
		end	
	end
	else if @p_report_info = 'sales_projection_count_opper'
	begin
		create table #sales_projection_count_opper (
			call_ref_no nvarchar(30),
			asset_id nvarchar(30),
			call_status varchar(30),
			asset_status bit,
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_count_opper (
			call_ref_no,
			asset_id,
			call_status, 
			asset_status,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select 
			a.call_ref_no,
			a.asset_id,
			a.call_status,
			a.asset_in_warranty_ind,
			a.equipment_id,
			isnull(b.equipment_type,'ZZZ'),
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date

		from call_register a
		left outer join equipment b
		on a.equipment_id = b.equipment_id
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.call_category in ('PE')
			and a.call_status in ('QS')
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = 4
			and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
					
		
		if @p_detail_view = 'true'
		begin
  			select '' as o_report_info,
				'{' +
					'"call_ref_no":"' + call_ref_no + '",' +
					'"asset_id":"' + asset_id + '",' +
					'"call_status":"' + call_status + '",' +
					'"asset_status":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"equipment_id":"' + equipment_id + '",' +
					'"equipment_type":"' + equipment_type + '",' +
					'"comp_loc":"' + company_location_code + '",' +
					'"org_lvl_code":"' + org_lvl_code + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_opper
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
		end
		else if @p_summary_by = 'company_location'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + company_location_code + '",' +
					'"summary_name":"' + company_location_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_opper
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by company_location_code
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_opper
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by org_lvl_code
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_opper
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by asset_status
		end
		else if @p_summary_by = 'month_wise'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + case(datepart(month, creation_date_time))
							when 1 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jan' 
							when 2 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Feb' 
							when 3 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Mar' 
							when 4 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Apr' 
							when 5 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'May' 
							when 6 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jun' 
							when 7 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jul' 
							when 8 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Aug' 
							when 9 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Sep' 
							when 10 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Oct' 
							when 11 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Nov' 
							when 12 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Dec' 
						end + '",' +
					'"summary_name":"' + case(datepart(month, creation_date_time))
							when 1 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jan'
							when 2 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Feb'
							when 3 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Mar'
							when 4 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Apr'
							when 5 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'May'
							when 6 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jun'
							when 7 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jul'
							when 8 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Aug'
							when 9 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Sep'
							when 10 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Oct'
							when 11 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Nov'
							when 12 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Dec'
						end + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_opper
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by datepart(month, creation_date_time), datepart(year, creation_date_time)
			order by datepart(year, creation_date_time) asc
		end
		else if @p_summary_by = 'equipment_type'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_opper
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by equipment_type
		end
	end
	else if @p_report_info = 'sales_projection_count_win'
	begin
		create table #sales_projection_count_win (
			call_ref_no nvarchar(30),
			asset_id nvarchar(30),
			call_status varchar(30),
			asset_status bit,
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7),
			closed_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_count_win (
			call_ref_no,
			asset_id,
			call_status, 
			asset_status,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time,
			closed_date_time
		)	
		select 
			a.call_ref_no,
			a.asset_id,
			a.call_status,
			a.asset_in_warranty_ind,
			a.equipment_id,
			isnull(b.equipment_type,'ZZZ'),
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date,
			a.closed_on_date
			
		from call_register a
		left outer join equipment b
		on a.equipment_id = b.equipment_id
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.call_category in ('PE')
			and a.call_status in ('CO')
			and a.won_lost_indicator  = '1'
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and datepart(month, a.created_on_date) = isnull(@p_month, isnull(datepart(month, a.created_on_date), ''))
			and a.organogram_level_no = 4
			and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
			and a.call_type != 'FCLOSURE'	
		
		if @p_detail_view = 'true'
		begin
  			select '' as o_report_info,
				'{' +
					'"call_ref_no":"' + call_ref_no + '",' +
					'"asset_id":"' + asset_id + '",' +
					'"call_status":"' + call_status + '",' +
					'"asset_status":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"equipment_id":"' + equipment_id + '",' +
					'"equipment_type":"' + equipment_type + '",' +
					'"comp_loc":"' + company_location_code + '",' +
					'"org_lvl_code":"' + org_lvl_code + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_win
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
		end
		else if @p_summary_by = 'company_location'	
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + company_location_code + '",' +
					'"summary_name":"' + company_location_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_win
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by company_location_code
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_win
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by org_lvl_code
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_win
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by asset_status
		end
		else if @p_summary_by = 'month'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + case(datepart(month, creation_date_time))
								when 1 then 'Jan'
								when 2 then 'Feb'
								when 3 then 'Mar'
								when 4 then 'Apr'
								when 5 then 'May'
								when 6 then 'Jun'
								when 7 then 'Jul'
								when 8 then 'Aug'
								when 9 then 'Sep'
								when 10 then 'Oct'
								when 11 then 'Nov'
								when 12 then 'Dec'
							end + '",' +
						'"summary_name":"' + case(datepart(month, creation_date_time))
								when 1 then 'Jan'
								when 2 then 'Feb'
								when 3 then 'Mar'
								when 4 then 'Apr'
								when 5 then 'May'
								when 6 then 'Jun'
								when 7 then 'Jul'
								when 8 then 'Aug'
								when 9 then 'Sep'
								when 10 then 'Oct'
								when 11 then 'Nov'
								when 12 then 'Dec'
							end + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_win
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by datepart(month, creation_date_time)
			order by datepart(month, creation_date_time) asc
		end
		else if @p_summary_by = 'equipment_type'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_win
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by equipment_type
		end
	end
	else if @p_report_info = 'sales_projection_value_opper'
	begin
		create table #sales_projection_value_opper (
			call_ref_no nvarchar(30),
			asset_id nvarchar(30),
			call_status  nvarchar(30),
			asset_status bit,
			charge_type varchar(10),
			charge_amount decimal(14,4),
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_value_opper (
			call_ref_no,
			asset_id,
			call_status,
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select 
			a.call_ref_no,
			a.asset_id,
			a.call_status,
			a.asset_in_warranty_ind,
			'Revenue', 
			a.proforma_net_amount,
			a.equipment_id,
			isnull(b.equipment_type,'ZZZ'),			
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date

		from call_register a
		left outer join equipment b
		on a.equipment_id = b.equipment_id
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.call_category in ('PE')
			and a.call_status in ('QS')
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = 4
			and a.charges_net_amount = '0'
			and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
		
		
		if @p_detail_view = 'true'
		begin
  			select '' as o_report_info,
				'{' +
					'"call_ref_no":"' + call_ref_no + '",' +
					'"asset_id":"' + asset_id + '",' +
					'"call_status":"' + call_status + '",' +
					'"asset_status":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + convert(varchar(20),charge_amount) + '",' +
					'"equipment_id":"' + equipment_id + '",' +
					'"equipment_type":"' + equipment_type + '",' +
					'"comp_loc":"' + company_location_code + '",' +
					'"org_lvl_code":"' + org_lvl_code + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_opper
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
		end
		else if @p_summary_by = 'company_location'	
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + company_location_code + '",' +
					'"summary_name":"' + company_location_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_opper
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by company_location_code
		end
		else if @p_summary_by = 'month_wise'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + case(datepart(month, creation_date_time))
							when 1 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jan' 
							when 2 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Feb' 
							when 3 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Mar' 
							when 4 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Apr' 
							when 5 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'May' 
							when 6 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jun' 
							when 7 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jul' 
							when 8 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Aug' 
							when 9 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Sep' 
							when 10 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Oct' 
							when 11 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Nov' 
							when 12 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Dec' 
						end + '",' +
					'"summary_name":"' + case(datepart(month, creation_date_time))
							when 1 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jan'
							when 2 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Feb'
							when 3 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Mar'
							when 4 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Apr'
							when 5 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'May'
							when 6 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jun'
							when 7 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jul'
							when 8 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Aug'
							when 9 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Sep'
							when 10 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Oct'
							when 11 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Nov'
							when 12 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Dec'
						end + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_opper
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by datepart(month, creation_date_time), datepart(year, creation_date_time)
			order by datepart(year, creation_date_time) asc
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_opper
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by org_lvl_code
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_opper
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by asset_status
		end
		else if @p_summary_by = 'equipment_type'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_opper
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by equipment_type
		end
	end
	else if @p_report_info = 'sales_projection_value_win'
	begin
		create table #sales_projection_value_win (
			call_ref_no nvarchar(30),
			asset_id nvarchar(30),
			call_status nvarchar(30),
			asset_status bit,
			charge_type varchar(10),
			charge_amount decimal(14,4),
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7),
			closed_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_value_win (
			call_ref_no,
			asset_id,
			call_status,
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time,
			closed_date_time
		)	
		select 
			a.call_ref_no,
			a.asset_id,
			a.call_status,
			a.asset_in_warranty_ind,
			'Revenue', 
			isnull(a.charges_net_amount,'0'),
			a.equipment_id,
			isnull(b.equipment_type,'ZZZ'),			
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date,
			a.closed_on_date
			
		from call_register a
		left outer join equipment b
		on a.equipment_id = b.equipment_id
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.call_category in ('PE')
			and a.call_status in ('CO')
			and a.won_lost_indicator  = '1'
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and datepart(month, a.created_on_date) = isnull(@p_month, isnull(datepart(month, a.created_on_date), ''))
			and a.organogram_level_no = 4
			and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
			and a.call_type != 'FCLOSURE'	
			
		if @p_detail_view = 'true'
		begin
  			select '' as o_report_info,
				'{' +
					'"call_ref_no":"' + call_ref_no + '",' +
					'"asset_id":"' + asset_id + '",' +
					'"call_status":"' + call_status + '",' +
					'"asset_status":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + convert(varchar(20),charge_amount) + '",' +
					'"equipment_id":"' + equipment_id + '",' +
					'"equipment_type":"' + equipment_type + '",' +
					'"comp_loc":"' + company_location_code + '",' +
					'"org_lvl_code":"' + org_lvl_code + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			/*and charge_amount != '0'*/
		end
		else if @p_summary_by = 'company_location'
		begin			
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + company_location_code + '",' +
					'"summary_name":"' + company_location_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by company_location_code
		end
		else if @p_summary_by = 'org_lvl_code'
		begin			
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by org_lvl_code
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by asset_status
		end
		else if @p_summary_by = 'month'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + case(datepart(month, creation_date_time))
								when 1 then 'Jan'
								when 2 then 'Feb'
								when 3 then 'Mar'
								when 4 then 'Apr'
								when 5 then 'May'
								when 6 then 'Jun'
								when 7 then 'Jul'
								when 8 then 'Aug'
								when 9 then 'Sep'
								when 10 then 'Oct'
								when 11 then 'Nov'
								when 12 then 'Dec'
							end + '",' +
						'"summary_name":"' + case(datepart(month, creation_date_time))
								when 1 then 'Jan'
								when 2 then 'Feb'
								when 3 then 'Mar'
								when 4 then 'Apr'
								when 5 then 'May'
								when 6 then 'Jun'
								when 7 then 'Jul'
								when 8 then 'Aug'
								when 9 then 'Sep'
								when 10 then 'Oct'
								when 11 then 'Nov'
								when 12 then 'Dec'
							end + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by datepart(month, creation_date_time)
			order by datepart(month, creation_date_time) asc
		end
		else if @p_summary_by = 'equipment_type'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by equipment_type
		end
	end
	else if @p_report_info = 'sales_projection_count_lost'
	begin
		create table #sales_projection_count_lost (
			call_ref_no nvarchar(30),
			asset_id nvarchar(30),
			call_status varchar(30),
			asset_status bit,
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7),
			closed_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_count_lost (
			call_ref_no,
			asset_id,
			call_status, 
			asset_status,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time,
			closed_date_time
		)	
		select 
			a.call_ref_no,
			a.asset_id,
			a.call_status,
			a.asset_in_warranty_ind,
			a.equipment_id,
			isnull(b.equipment_type,'ZZZ'),
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date,
			a.closed_on_date
			
		from call_register a
		left outer join equipment b
		on a.equipment_id = b.equipment_id
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.call_category in ('PE')
			and a.call_status in ('CO')
			and a.won_lost_indicator  = '0'
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and datepart(month, a.created_on_date) = isnull(@p_month, isnull(datepart(month, a.created_on_date), ''))
			and a.organogram_level_no = 4
			and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
			/*and a.charges_net_amount = '0'*/	
			and a.call_type != 'FCLOSURE'	
		
		if @p_detail_view = 'true'
			begin
  				select '' as o_report_info,
					'{' +
						'"call_ref_no":"' + call_ref_no + '",' +
						'"asset_id":"' + asset_id + '",' +
						'"call_status":"' + call_status + '",' +
						'"asset_status":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"comp_loc":"' + company_location_code + '",' +
						'"org_lvl_code":"' + org_lvl_code + '"' +
					'}' as o_report_info_json
				from #sales_projection_count_lost
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			end
		else if @p_summary_by = 'company_location'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + company_location_code + '",' +
					'"summary_name":"' + company_location_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lost
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by company_location_code
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lost
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by org_lvl_code
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lost
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by asset_status
		end
		else if @p_summary_by = 'month'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + case(datepart(month, creation_date_time))
								when 1 then 'Jan'
								when 2 then 'Feb'
								when 3 then 'Mar'
								when 4 then 'Apr'
								when 5 then 'May'
								when 6 then 'Jun'
								when 7 then 'Jul'
								when 8 then 'Aug'
								when 9 then 'Sep'
								when 10 then 'Oct'
								when 11 then 'Nov'
								when 12 then 'Dec'
							end + '",' +
						'"summary_name":"' + case(datepart(month, creation_date_time))
								when 1 then 'Jan'
								when 2 then 'Feb'
								when 3 then 'Mar'
								when 4 then 'Apr'
								when 5 then 'May'
								when 6 then 'Jun'
								when 7 then 'Jul'
								when 8 then 'Aug'
								when 9 then 'Sep'
								when 10 then 'Oct'
								when 11 then 'Nov'
								when 12 then 'Dec'
							end + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lost
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by datepart(month, creation_date_time)
			order by datepart(month, creation_date_time) asc
		end
		else if @p_summary_by = 'equipment_type'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lost
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by equipment_type
		end
	end
	else if @p_report_info = 'sales_projection_value_lost'
	begin
		create table #sales_projection_value_lost (
			call_ref_no nvarchar(30),
			asset_id nvarchar(30),
			call_status nvarchar(30),
			asset_status bit,
			charge_type varchar(10),
			charge_amount decimal(14,4),
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7),
			closed_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_value_lost (
			call_ref_no,
			asset_id,
			call_status,
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time,
			closed_date_time
		)	
		select 
			a.call_ref_no,
			a.asset_id,
			a.call_status,
			a.asset_in_warranty_ind,
			'Revenue', 
			a.charges_net_amount,
			a.equipment_id,
			isnull(b.equipment_type,'ZZZ'),			
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date,
			a.closed_on_date
			
		from call_register a
		left outer join equipment b
		on a.equipment_id = b.equipment_id
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.call_category in ('PE')
			and a.call_status in ('CO')
			and a.won_lost_indicator  = '0'
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and datepart(month, a.created_on_date) = isnull(@p_month, isnull(datepart(month, a.created_on_date), ''))
			and a.organogram_level_no = 4
			and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
			--and a.charges_net_amount = '0'
			and a.call_type != 'FCLOSURE'	
		
		
		if @p_detail_view = 'true'
		begin
  			select '' as o_report_info,
				'{' +
					'"call_ref_no":"' + call_ref_no + '",' +
					'"asset_id":"' + asset_id + '",' +
					'"call_status":"' + call_status + '",' +
					'"asset_status":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + convert(varchar(20),charge_amount) + '",' +
					'"equipment_id":"' + equipment_id + '",' +
					'"equipment_type":"' + equipment_type + '",' +
					'"comp_loc":"' + company_location_code + '",' +
					'"org_lvl_code":"' + org_lvl_code + '"' +
				'}' as o_report_info_json
				from #sales_projection_value_lost
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
		end
		else if @p_summary_by = 'company_location'	
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + company_location_code + '",' +
					'"summary_name":"' + company_location_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_lost
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by company_location_code
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_lost
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by org_lvl_code
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_lost
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by asset_status
		end
		else if @p_summary_by = 'month'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + case(datepart(month, creation_date_time))
								when 1 then 'Jan'
								when 2 then 'Feb'
								when 3 then 'Mar'
								when 4 then 'Apr'
								when 5 then 'May'
								when 6 then 'Jun'
								when 7 then 'Jul'
								when 8 then 'Aug'
								when 9 then 'Sep'
								when 10 then 'Oct'
								when 11 then 'Nov'
								when 12 then 'Dec'
							end + '",' +
						'"summary_name":"' + case(datepart(month, creation_date_time))
								when 1 then 'Jan'
								when 2 then 'Feb'
								when 3 then 'Mar'
								when 4 then 'Apr'
								when 5 then 'May'
								when 6 then 'Jun'
								when 7 then 'Jul'
								when 8 then 'Aug'
								when 9 then 'Sep'
								when 10 then 'Oct'
								when 11 then 'Nov'
								when 12 then 'Dec'
							end + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_lost
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by datepart(month, creation_date_time)
			order by datepart(month, creation_date_time) asc
		end
		else if @p_summary_by = 'equipment_type'
		begin		
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_lost
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by equipment_type
		end
	end

	/* End of lead and Opportunity */

	else if @p_report_info = 'sales_projection_value'
	begin
		create table #sales_projection_value (
			call_ref_no nvarchar(30),
			call_status varchar(30),
			asset_id nvarchar(30),
			asset_status nvarchar(30),
			charge_type varchar(10),
			charge_amount decimal(14,4),
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_value (
			call_ref_no,
			call_status, 
			asset_id,
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.call_ref_no,
			( case(a.call_status)
			when 'O' then 'Not Progressed'
			when 'A' then 'Not Progressed'
			when 'QG' then 'Not Progressed'
			when 'QS' then 'Quoted'
			else (
				case (isnull(a.won_lost_indicator,0))
					when 0 then 'Lost'
					else 'Won'
				end
			)
			end	),
			a.asset_id,
			a.asset_in_warranty_ind,
			'Revenue', 
			a.proforma_net_amount,
			a.equipment_id,
			b.equipment_type,			
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'PE'
			and a.equipment_id != 'ZZZ'
			and a.equipment_id = b.equipment_id
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.charges_net_amount = '0'
			and a.organogram_level_no = '4'
			and a.call_type != 'FCLOSURE'	
		
		insert #sales_projection_value (
			call_ref_no,
			call_status,
			asset_id, 
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.call_ref_no,
			( case(a.call_status)
			when 'O' then 'Not Progressed'
			when 'A' then 'Not Progressed'
			when 'QG' then 'Not Progressed'
			when 'QS' then 'Quoted'
			else (
				case (isnull(a.won_lost_indicator,0))
					when 0 then 'Lost'
					else 'Won'
				end
			)
			end	),
			a.asset_id,
			a.asset_in_warranty_ind,
			'Revenue', 
			a.charges_net_amount, 
			a.equipment_id,
			b.equipment_type,
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'PE'
			and a.equipment_id != 'ZZZ'
			and a.equipment_id = b.equipment_id
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = '4'	
			and a.call_type != 'FCLOSURE'	
			
		insert #sales_projection_value (
			call_ref_no,
			call_status,
			asset_id,
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.call_ref_no,
			( case(a.call_status)
			when 'O' then 'Not Progressed'
			when 'A' then 'Not Progressed'
			when 'QG' then 'Not Progressed'
			when 'QS' then 'Quoted'
			else (
				case (isnull(a.won_lost_indicator,0))
					when 0 then 'Lost'
					else 'Won'
				end
			)
			end	),
			a.asset_id,
			a.asset_in_warranty_ind,
			'Revenue', 
			a.udf_float_2, 
			a.equipment_id,
			b.equipment_type,
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'EQ'
			and a.equipment_id != 'ZZZ'
			and a.equipment_id = b.equipment_id
			and a.udf_float_3 = '0'
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = '4'	
			and a.call_type != 'FCLOSURE'	
		
		insert #sales_projection_value (
			call_ref_no,
			call_status,
			asset_id,
			asset_status,			
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.call_ref_no,
			( case(a.call_status)
			when 'O' then 'Not Progressed'
			when 'A' then 'Not Progressed'
			when 'QG' then 'Not Progressed'
			when 'QS' then 'Quoted'
			else (
				case (isnull(a.won_lost_indicator,0))
					when 0 then 'Lost'
					else 'Won'
				end
			)
			end	),
			a.asset_id,
			a.asset_in_warranty_ind,
			'Revenue', 
			a.udf_float_3, 
			a.equipment_id,
			b.equipment_type,
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'EQ'
			and a.equipment_id != 'ZZZ'
			and a.equipment_id = b.equipment_id
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = '4'	
			and a.call_type != 'FCLOSURE'	
		
		if @p_detail_view = 'true'
			begin
  				select '' as o_report_info,
				'{' +
					'"call_ref_no":"' + call_ref_no + '",' +
					'"call_status":"' + call_status + '",' +
					'"asset_id":"' + asset_id + '",' +
					'"asset_status":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"summary_name":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
					'"charge_type":"' + charge_type + '",' +
					'"charge_amount":"' + isnull(convert(varchar(20), charge_amount),'0') + '",' +
					'"equipment_id":"' + equipment_id + '",' +
					'"equipment_type":"' + equipment_type + '",' +
					'"org_lvl_code":"' + org_lvl_code + '",' +	
					'"comp_loc":"' + company_location_code + '"' +
				'}' as o_report_info_json
			from #sales_projection_value
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and charge_amount != '0'			
			end	 	
    	else if @p_summary_by = 'company_location'	
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + company_location_code + '",' +
					'"summary_name":"' + company_location_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by company_location_code			
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by org_lvl_code
		end
		else if @p_summary_by = 'call_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + call_status + '",' +
					'"summary_name":"' + call_status + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by call_status
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by asset_status
		end
		else if @p_summary_by = 'equipment_type'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + '' + '",' +
					'"series_name":"' + '' + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by equipment_type
		end
	end
	else if @p_report_info = 'sales_projection_leadsource'
	begin

		declare @p_lead_source nvarchar (10)
		
		select @p_lead_source = paramval from #input_params where paramname = 'lead_source'

		create table #sales_projection_leadsource (
			lead_source varchar(10),
			asset_status nvarchar(30),
			charge_type varchar(10),
			charge_amount decimal(14,4),
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_leadsource (
			lead_source, 
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.udf_char_4,
			a.asset_in_warranty_ind,
			'Quoted', 
			a.proforma_net_amount,
			a.equipment_id,
			b.equipment_type,			
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'PE'
			and a.equipment_id != 'ZZZ'
			and a.equipment_id = b.equipment_id
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.charges_net_amount = '0'
			and a.udf_char_4 != ''
			and a.organogram_level_no = '4'
			and a.call_type != 'FCLOSURE'	
		
		insert #sales_projection_leadsource (
			lead_source, 
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.udf_char_4,
			a.asset_in_warranty_ind,
			'Invoiced', 
			a.charges_net_amount, 
			a.equipment_id,
			b.equipment_type,
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'PE'
			and a.equipment_id != 'ZZZ'
			and a.udf_char_4 != ''
			and a.equipment_id = b.equipment_id
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = '4'	
			and a.call_type != 'FCLOSURE'	
			
		insert #sales_projection_leadsource (
			lead_source,
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.udf_char_4,
			a.asset_in_warranty_ind,
			'Quoted', 
			a.udf_float_2, 
			a.equipment_id,
			b.equipment_type,
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'EQ'
			and a.equipment_id != 'ZZZ'
			and a.equipment_id = b.equipment_id
			and a.udf_float_3 = '0'
			and a.udf_char_4 != ''
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = '4'	
			and a.call_type != 'FCLOSURE'	
		
		insert #sales_projection_leadsource (
			lead_source,
			asset_status,			
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.udf_char_4,
			a.asset_in_warranty_ind,
			'Invoiced', 
			a.udf_float_3, 
			a.equipment_id,
			b.equipment_type,
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'EQ'
			and a.equipment_id != 'ZZZ'
			and a.udf_char_4 != ''
			and a.equipment_id = b.equipment_id
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = '4'			
			and a.call_type != 'FCLOSURE'	
		
		
	    if @p_summary_by = 'company_location'	
		begin
			if @p_detail_view = 'true'
			begin
  			    select '' as o_report_info,
					'{' +
						'"lead_source":"' + lead_source + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + isnull(convert(varchar(20), charge_amount),'0') + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"org_lvl_code":"' + org_lvl_code + '",' +
						'"comp_loc":"' + company_location_code + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				and charge_amount != '0'
			end
			else
			begin			
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + company_location_code + '",' +
						'"summary_name":"' + company_location_code + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				group by company_location_code
			end
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			if @p_detail_view = 'true'
			begin
  			   select '' as o_report_info,
					'{' +
						'"lead_source":"' + lead_source + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + isnull(convert(varchar(20), charge_amount),'0') + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"org_lvl_code":"' + org_lvl_code + '",' +
						'"comp_loc":"' + company_location_code + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				and charge_amount != '0'
			end
			else
			begin			
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + org_lvl_code + '",' +
						'"summary_name":"' + org_lvl_code + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				group by org_lvl_code
			end
		end
		else if @p_summary_by = 'lead_source'
		begin
			if @p_detail_view = 'true'
			begin
  			    select '' as o_report_info,
					'{' +
						'"lead_source":"' + lead_source + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + isnull(convert(varchar(20), charge_amount),'0') + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"org_lvl_code":"' + org_lvl_code + '",' +
						'"comp_loc":"' + company_location_code + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				and charge_amount != '0'
			end
			else
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + lead_source + '",' +
						'"summary_name":"' + lead_source + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				group by lead_source
			end
		end
		else if @p_summary_by = 'asset_status'
		begin
			if @p_detail_view = 'true'
			begin

  			   select '' as o_report_info,
					'{' +
						'"lead_source":"' + lead_source + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + isnull(convert(varchar(20), charge_amount),'0') + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"org_lvl_code":"' + org_lvl_code + '",' +
						'"comp_loc":"' + company_location_code + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				and charge_amount != '0'
			end
			else
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"summary_name":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				group by asset_status
			end
		end
		else if @p_summary_by = 'equipment_type'
		begin
			if @p_detail_view = 'true'
			begin
  			   select '' as o_report_info,
					'{' +
						'"lead_source":"' + lead_source + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + isnull(convert(varchar(20), charge_amount),'0') + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"org_lvl_code":"' + org_lvl_code + '",' +
						'"comp_loc":"' + company_location_code + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				and charge_amount != '0'
			end
			else
			begin
			
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + equipment_type + '",' +
						'"summary_name":"' + equipment_type + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				group by equipment_type
			end
		end
	end
	else if @p_report_info = 'sales_projection_leadsource_count'
	begin

		select @p_lead_source = paramval from #input_params where paramname = 'lead_source'

		create table #sales_projection_leadsource_count (
			lead_source varchar(10),
			asset_status nvarchar(30),
			charge_type varchar(10),
			charge_amount decimal(14,4),
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_leadsource_count (
			lead_source, 
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.udf_char_4,
			a.asset_in_warranty_ind,
			'Quoted', 
			a.proforma_net_amount,
			a.equipment_id,
			b.equipment_type,			
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'PE'
			and a.equipment_id != 'ZZZ'
			and a.equipment_id = b.equipment_id
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.charges_net_amount = '0'
			and a.udf_char_4 != ''
			and a.organogram_level_no = '4'
			and a.call_type != 'FCLOSURE'	
		
		insert #sales_projection_leadsource_count (
			lead_source, 
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.udf_char_4,
			a.asset_in_warranty_ind,
			'Invoiced', 
			a.charges_net_amount, 
			a.equipment_id,
			b.equipment_type,
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'PE'
			and a.equipment_id != 'ZZZ'
			and a.udf_char_4 != ''
			and a.equipment_id = b.equipment_id
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = '4'	
			and a.call_type != 'FCLOSURE'	
			
		insert #sales_projection_leadsource_count (
			lead_source,
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.udf_char_4,
			a.asset_in_warranty_ind,
			'Quoted', 
			a.udf_float_2, 
			a.equipment_id,
			b.equipment_type,
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'EQ'
			and a.equipment_id != 'ZZZ'
			and a.equipment_id = b.equipment_id
			and a.udf_float_3 = '0'
			and a.udf_char_4 != ''
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = '4'	
			and a.call_type != 'FCLOSURE'	
		
		insert #sales_projection_leadsource_count (
			lead_source,
			asset_status,			
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time
		)	
		select a.udf_char_4,
			a.asset_in_warranty_ind,
			'Invoiced', 
			a.udf_float_3, 
			a.equipment_id,
			b.equipment_type,
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date
			
		from call_register a, equipment b
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.company_id = b.company_id
			and a.country_code = b.country_code
			and a.call_category = 'EQ'
			and a.equipment_id != 'ZZZ'
			and a.udf_char_4 != ''
			and a.equipment_id = b.equipment_id
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = '4'			
			and a.call_type != 'FCLOSURE'	
		
		
	    if @p_summary_by = 'company_location'	
		begin
			if @p_detail_view = 'true'
			begin
  			    select '' as o_report_info,
					'{' +
						'"lead_source":"' + lead_source + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + isnull(convert(varchar(20), charge_amount),'0') + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"org_lvl_code":"' + org_lvl_code + '",' +
						'"comp_loc":"' + company_location_code + '"' +
						
					'}' as o_report_info_json
				from #sales_projection_leadsource_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				/*and charge_amount != '0'*/
			end
			else
			begin			
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + company_location_code + '",' +
						'"summary_name":"' + company_location_code + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
						/*'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +*/
					'}' as o_report_info_json
				from #sales_projection_leadsource_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				group by company_location_code
			end
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			if @p_detail_view = 'true'
			begin
  			   select '' as o_report_info,
					'{' +
						'"lead_source":"' + lead_source + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + isnull(convert(varchar(20), charge_amount),'0') + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"org_lvl_code":"' + org_lvl_code + '",' +
						'"comp_loc":"' + company_location_code + '"' +
						
					'}' as o_report_info_json
				from #sales_projection_leadsource_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				/*and charge_amount != '0'*/
			end
			else
			begin			
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + org_lvl_code + '",' +
						'"summary_name":"' + org_lvl_code + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
						/*'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +*/
					'}' as o_report_info_json
				from #sales_projection_leadsource_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				group by org_lvl_code
			end
		end
		else if @p_summary_by = 'lead_source'
		begin
			if @p_detail_view = 'true'
			begin
  			    select '' as o_report_info,
					'{' +
						'"lead_source":"' + lead_source + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + isnull(convert(varchar(20), charge_amount),'0') + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"org_lvl_code":"' + org_lvl_code + '",' +
						'"comp_loc":"' + company_location_code + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				/*and charge_amount != '0'*/
			end
			else
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + lead_source + '",' +
						'"summary_name":"' + lead_source + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
						/*'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +*/
					'}' as o_report_info_json
				from #sales_projection_leadsource_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				group by lead_source
			end
		end
		else if @p_summary_by = 'asset_status'
		begin
			if @p_detail_view = 'true'
			begin

  			   select '' as o_report_info,
					'{' +
						'"lead_source":"' + lead_source + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + isnull(convert(varchar(20), charge_amount),'0') + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"org_lvl_code":"' + org_lvl_code + '",' +
						'"comp_loc":"' + company_location_code + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				/*and charge_amount != '0'*/
			end
			else
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"summary_name":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
						/*'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +*/
					'}' as o_report_info_json
				from #sales_projection_leadsource_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				group by asset_status
			end
		end
		else if @p_summary_by = 'equipment_type'
		begin
			if @p_detail_view = 'true'
			begin
  			   select '' as o_report_info,
					'{' +
						'"lead_source":"' + lead_source + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + isnull(convert(varchar(20), charge_amount),'0') + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"org_lvl_code":"' + org_lvl_code + '",' +
						'"comp_loc":"' + company_location_code + '"' +
					'}' as o_report_info_json
				from #sales_projection_leadsource_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				/*and charge_amount != '0'*/
			end
			else
			begin
			
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + equipment_type + '",' +
						'"summary_name":"' + equipment_type + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
						/*'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +*/
					'}' as o_report_info_json
				from #sales_projection_leadsource_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				and isnull(lead_source, '') = isnull(@p_lead_source, isnull(lead_source, ''))
				group by equipment_type
			end
		end
	end


	else if @p_report_info = 'sales_projection_win_vs_lost_count'
	begin
			create table #sales_projection_win_vs_lost_count (
				call_ref_no nvarchar(30),
				asset_id nvarchar(30),
				call_status varchar(30),
				projection_type nvarchar(10),
				asset_status bit,
				equipment_id nvarchar(30),
				equipment_type nvarchar(60),
				company_location_code varchar(10),
				org_lvl_no tinyint,
				org_lvl_code nvarchar(15),
				creation_date_time datetimeoffset(7),
				closed_date_time datetimeoffset(7)			
			)
		
			insert #sales_projection_win_vs_lost_count (
				call_ref_no,
				asset_id,
				call_status,
				projection_type, 
				asset_status,
				equipment_id, 
				equipment_type,
				company_location_code,
				org_lvl_no,
				org_lvl_code,
				creation_date_time,
				closed_date_time
			)	
			select 
				a.call_ref_no,
				a.asset_id,
				a.call_status,
				'Won',
				a.asset_in_warranty_ind,
				a.equipment_id,
				isnull(b.equipment_type,'ZZZ'),
				a.company_location_code,
				a.organogram_level_no,
				a.organogram_level_code,
				a.created_on_date,
				a.closed_on_date
			
			from call_register a
			left outer join equipment b
			on a.equipment_id = b.equipment_id
				and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
				and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			where a.company_id = @i_client_id
				and a.country_code = @i_country_code
				and a.call_category in ('PE')
				and a.call_status in ('CO')
				and a.won_lost_indicator  = '1'
				and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
				and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
				and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
				and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
				and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
				and datepart(month, a.created_on_date) = isnull(@p_month, isnull(datepart(month, a.created_on_date), ''))
				and a.organogram_level_no = 4
				and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
			
			
			insert #sales_projection_win_vs_lost_count (
				call_ref_no,
				asset_id,
				call_status,
				projection_type, 
				asset_status,
				equipment_id, 
				equipment_type,
				company_location_code,
				org_lvl_no,
				org_lvl_code,
				creation_date_time,
				closed_date_time
			)	
			select 
				a.call_ref_no,
				a.asset_id,
				a.call_status,
				'Lost',
				a.asset_in_warranty_ind,
				a.equipment_id,
				isnull(b.equipment_type,'ZZZ'),
				a.company_location_code,
				a.organogram_level_no,
				a.organogram_level_code,
				a.created_on_date,
				a.closed_on_date

			from call_register a
			left outer join equipment b
			on a.equipment_id = b.equipment_id
				and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
				and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			where a.company_id = @i_client_id
				and a.country_code = @i_country_code
				and a.call_category in ('PE')
				and a.call_status in ('CO')
				and a.won_lost_indicator  = '0'
				and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
				and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
				and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
				and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
				and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
				and datepart(month, a.created_on_date) = isnull(@p_month, isnull(datepart(month, a.created_on_date), ''))
				and a.organogram_level_no = 4
				and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
					
		
			if @p_detail_view = 'true'
			begin
  				select '' as o_report_info,
					'{' +
						'"call_ref_no":"' + call_ref_no + '",' +
						'"asset_id":"' + asset_id + '",' +
						'"call_status":"' + call_status + '",' +
						'"asset_status":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"equipment_id":"' + equipment_id + '",' +
						'"equipment_type":"' + equipment_type + '",' +
						'"comp_loc":"' + company_location_code + '",' +
						'"projection_type":"' + projection_type + '",' +
						'"org_lvl_code":"' + org_lvl_code + '"' +
					'}' as o_report_info_json
				from #sales_projection_win_vs_lost_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			end
			else if @p_summary_by = 'company_location'	
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + company_location_code + '",' +
						'"summary_name":"' + company_location_code + '",' +
						'"series_by":"' + projection_type + '",' +
						'"series_name":"' + projection_type + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
					'}' as o_report_info_json
				from #sales_projection_win_vs_lost_count 
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				group by company_location_code, projection_type
			end
			else if @p_summary_by = 'org_lvl_code'
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + org_lvl_code + '",' +
						'"summary_name":"' + org_lvl_code + '",' +
						'"series_by":"' + projection_type + '",' +
						'"series_name":"' + projection_type + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
					'}' as o_report_info_json
				from #sales_projection_win_vs_lost_count 
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				group by org_lvl_code, projection_type
			end
			else if @p_summary_by = 'asset_status'
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"summary_name":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"series_by":"' + projection_type + '",' +
						'"series_name":"' + projection_type + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
					'}' as o_report_info_json
				from #sales_projection_win_vs_lost_count 
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				group by asset_status, projection_type
			end
			else if @p_summary_by = 'month'
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + case(datepart(month, creation_date_time))
									when 1 then 'Jan'
									when 2 then 'Feb'
									when 3 then 'Mar'
									when 4 then 'Apr'
									when 5 then 'May'
									when 6 then 'Jun'
									when 7 then 'Jul'
									when 8 then 'Aug'
									when 9 then 'Sep'
									when 10 then 'Oct'
									when 11 then 'Nov'
									when 12 then 'Dec'
								end + '",' +
							'"summary_name":"' + case(datepart(month, creation_date_time))
									when 1 then 'Jan'
									when 2 then 'Feb'
									when 3 then 'Mar'
									when 4 then 'Apr'
									when 5 then 'May'
									when 6 then 'Jun'
									when 7 then 'Jul'
									when 8 then 'Aug'
									when 9 then 'Sep'
									when 10 then 'Oct'
									when 11 then 'Nov'
									when 12 then 'Dec'
								end + '",' +
						'"series_by":"' + projection_type + '",' +
						'"series_name":"' + projection_type + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
					'}' as o_report_info_json
				from #sales_projection_win_vs_lost_count
				where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
				and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				group by datepart(month, creation_date_time), projection_type
				order by datepart(month, creation_date_time) asc
			end
			else if @p_summary_by = 'equipment_type'
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + equipment_type + '",' +
						'"summary_name":"' + equipment_type + '",' +
						'"series_by":"' + projection_type + '",' +
						'"series_name":"' + projection_type + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
					'}' as o_report_info_json
				from #sales_projection_win_vs_lost_count
				where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
				group by equipment_type, projection_type
			end
		end

	else if @p_report_info = 'sales_projection_value_win_vs_lost_value'
	begin
		create table #sales_projection_value_win_vs_lost_value (
			call_ref_no nvarchar(30),
			asset_id nvarchar(30),
			call_status nvarchar(30),
			asset_status bit,
			charge_type varchar(10),
			charge_amount decimal(14,4),
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			creation_date_time datetimeoffset(7),
			closed_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_value_win_vs_lost_value (
			call_ref_no,
			asset_id,
			call_status,
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time,
			closed_date_time
		)	
		select 
			a.call_ref_no,
			a.asset_id,
			a.call_status,
			a.asset_in_warranty_ind,
			'Win', 
			isnull(a.charges_net_amount,'0'),
			a.equipment_id,
			isnull(b.equipment_type,'ZZZ'),			
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date,
			a.closed_on_date

		from call_register a
		left outer join equipment b
		on a.equipment_id = b.equipment_id
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.call_category in ('PE')
			and a.call_status in ('CO')
			and a.won_lost_indicator  = '1'
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and datepart(month, a.created_on_date) = isnull(@p_month, isnull(datepart(month, a.created_on_date), ''))
			and a.organogram_level_no = 4
			and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )


	insert #sales_projection_value_win_vs_lost_value (
			call_ref_no,
			asset_id,
			call_status,
			asset_status,
			charge_type, 
			charge_amount,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			creation_date_time,
			closed_date_time
		)	
		select 
			a.call_ref_no,
			a.asset_id,
			a.call_status,
			a.asset_in_warranty_ind,
			'Lost', 
			a.charges_net_amount,
			a.equipment_id,
			isnull(b.equipment_type,'ZZZ'),			
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			a.created_on_date,
			a.closed_on_date

		from call_register a
		left outer join equipment b
		on a.equipment_id = b.equipment_id
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.call_category in ('PE')
			and a.call_status in ('CO')
			and a.won_lost_indicator  = '0'
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and datepart(month, a.created_on_date) = isnull(@p_month, isnull(datepart(month, a.created_on_date), ''))
			and a.organogram_level_no = 4
			and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
		
		
		
		if @p_detail_view = 'true'
		begin
  			select '' as o_report_info,
				'{' +
					'"call_ref_no":"' + call_ref_no + '",' +
					'"asset_id":"' + asset_id + '",' +
					'"call_status":"' + call_status + '",' +
					'"asset_status":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
						'"charge_type":"' + charge_type + '",' +
						'"charge_amount":"' + convert(varchar(20),charge_amount) + '",' +
					'"equipment_id":"' + equipment_id + '",' +
					'"equipment_type":"' + equipment_type + '",' +
					'"comp_loc":"' + company_location_code + '",' +
					'"org_lvl_code":"' + org_lvl_code + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win_vs_lost_value
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			and charge_amount != '0'
		end
		else if @p_summary_by = 'company_location'
		begin			
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + company_location_code + '",' +
					'"summary_name":"' + company_location_code + '",' +
					'"series_by":"' + charge_type + '",' +
					'"series_name":"' + charge_type + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win_vs_lost_value
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by charge_type,company_location_code
		end
		else if @p_summary_by = 'org_lvl_code'
		begin			
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + charge_type + '",' +
					'"series_name":"' + charge_type + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win_vs_lost_value
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by charge_type,org_lvl_code
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + charge_type + '",' +
					'"series_name":"' + charge_type + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win_vs_lost_value
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by charge_type,asset_status
		end
		else if @p_summary_by = 'month'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + case(datepart(month, creation_date_time))
								when 1 then 'Jan'
								when 2 then 'Feb'
								when 3 then 'Mar'
								when 4 then 'Apr'
								when 5 then 'May'
								when 6 then 'Jun'
								when 7 then 'Jul'
								when 8 then 'Aug'
								when 9 then 'Sep'
								when 10 then 'Oct'
								when 11 then 'Nov'
								when 12 then 'Dec'
							end + '",' +
						'"summary_name":"' + case(datepart(month, creation_date_time))
								when 1 then 'Jan'
								when 2 then 'Feb'
								when 3 then 'Mar'
								when 4 then 'Apr'
								when 5 then 'May'
								when 6 then 'Jun'
								when 7 then 'Jul'
								when 8 then 'Aug'
								when 9 then 'Sep'
								when 10 then 'Oct'
								when 11 then 'Nov'
								when 12 then 'Dec'
							end + '",' +
					'"series_by":"' + charge_type + '",' +
					'"series_name":"' + charge_type + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win_vs_lost_value
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by datepart(month, creation_date_time),charge_type
			order by datepart(month, creation_date_time) asc
		end
		else if @p_summary_by = 'equipment_type'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + charge_type + '",' +
					'"series_name":"' + charge_type + '",' +
					'"count":"' + isnull(convert(varchar(20), convert(int, SUM(charge_amount)/1000)),'0') + '"' +
				'}' as o_report_info_json
			from #sales_projection_value_win_vs_lost_value
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by charge_type,equipment_type
		end
	end
	
	

	else if @p_report_info = 'sales_projection_count_lead_leadsource'
	begin
		create table #sales_projection_count_lead_leadsource (

			call_ref_no nvarchar(30),
			asset_id nvarchar(30),
			call_status varchar(30),
			asset_status bit,
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			lead_source nvarchar(30),
			creation_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_count_lead_leadsource (
			call_ref_no,
			asset_id,
			call_status, 
			asset_status,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			lead_source,
			creation_date_time
		)	
		select 
			a.call_ref_no,
			a.asset_id,
			a.call_status,
			a.asset_in_warranty_ind,
			a.equipment_id,
			isnull(b.equipment_type,'ZZZ'),
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			(CASE (a.udf_char_4 )
				 WHEN '' THEN 'ZZZ'
				 ELSE a.udf_char_4
			 END),
			a.created_on_date			
		from call_register a
		left outer join equipment b
		on a.equipment_id = b.equipment_id
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.call_category in ('PE')
			and a.call_status in ('O','A','I','QG')
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = 4
			and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
		
		if @p_detail_view = 'true'
		begin
  			select '' as o_report_info,
				'{' +
					'"call_ref_no":"' + call_ref_no + '",' +
					'"asset_id":"' + asset_id + '",' +
					'"call_status":"' + call_status + '",' +
					'"asset_status":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"equipment_id":"' + isnull(equipment_id,'ZZZ') + '",' +
					'"equipment_type":"' + isnull(equipment_type,'ZZZ') + '",' +
					'"comp_loc":"' + isnull(company_location_code,'ZZZ') + '",' +
					'"org_lvl_code":"' + isnull(org_lvl_code,'ZZZ') + '",' +
					'"lead_source":"' + isnull(lead_source,'ZZZ') + '"' +

				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsource
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
		end			
		else if @p_summary_by = 'company_location'	
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + isnull(company_location_code,'ZZZ') + '",' +
					'"summary_name":"' + isnull(company_location_code,'ZZZ') + '",' +
					'"series_by":"' + isnull(lead_source,'ZZZ') + '",' +
					'"series_name":"' + isnull(lead_source,'ZZZ') + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsource
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by company_location_code,lead_source		
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + isnull(lead_source,'ZZZ') + '",' +
					'"series_name":"' + isnull(lead_source,'ZZZ') + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsource
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by org_lvl_code,lead_source
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + isnull(lead_source,'ZZZ') + '",' +
					'"series_name":"' + isnull(lead_source,'ZZZ') + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsource
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by asset_status,lead_source
		end
		else if @p_summary_by = 'month_wise'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + case(datepart(month, creation_date_time))
							when 1 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jan' 
							when 2 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Feb' 
							when 3 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Mar' 
							when 4 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Apr' 
							when 5 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'May' 
							when 6 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jun' 
							when 7 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jul' 
							when 8 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Aug' 
							when 9 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Sep' 
							when 10 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Oct' 
							when 11 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Nov' 
							when 12 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Dec' 
						end + '",' +
					'"summary_name":"' + case(datepart(month, creation_date_time))
							when 1 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jan'
							when 2 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Feb'
							when 3 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Mar'
							when 4 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Apr'
							when 5 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'May'
							when 6 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jun'
							when 7 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jul'
							when 8 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Aug'
							when 9 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Sep'
							when 10 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Oct'
							when 11 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Nov'
							when 12 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Dec'
						end + '",' +
					'"series_by":"' + isnull(lead_source,'ZZZ') + '",' +
					'"series_name":"' + isnull(lead_source,'ZZZ') + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsource
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by datepart(month, creation_date_time), datepart(year, creation_date_time),lead_source
			order by datepart(year, creation_date_time) asc
		end
		else if @p_summary_by = 'equipment_type'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + isnull(lead_source,'ZZZ') + '",' +
					'"series_name":"' + isnull(lead_source,'ZZZ') + '",' +
					'"count":"' + convert(varchar(5), count(*)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsource
			/*where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())*/
			group by equipment_type, lead_source
		end	
	end
	
	else if @p_report_info = 'sales_projection_count_lead_leadsourcep'
	begin
		create table #sales_projection_count_lead_leadsourcep (

			call_ref_no nvarchar(30),
			asset_id nvarchar(30),
			call_status varchar(30),
			asset_status bit,
			equipment_id nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			lead_source nvarchar(30),
			creation_date_time datetimeoffset(7)			
		)
		
		insert #sales_projection_count_lead_leadsourcep (
			call_ref_no,
			asset_id,
			call_status, 
			asset_status,
			equipment_id, 
			equipment_type,
			company_location_code,
			org_lvl_no,
			org_lvl_code,
			lead_source,
			creation_date_time
		)	
		select 
			a.call_ref_no,
			a.asset_id,
			a.call_status,
			a.asset_in_warranty_ind,
			a.equipment_id,
			isnull(b.equipment_type,'ZZZ'),
            a.company_location_code,
			a.organogram_level_no,
			a.organogram_level_code,
			(CASE (a.udf_char_4 )
				 WHEN '' THEN 'ZZZ'
				 ELSE a.udf_char_4
			 END),
			a.created_on_date			
		from call_register a
		left outer join equipment b
		on a.equipment_id = b.equipment_id
			and isnull(b.equipment_category, '') = isnull(@p_equipment_category, isnull(b.equipment_category, ''))
			and isnull(b.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
			and isnull(b.equipment_type, '') = isnull(@p_equipment_type, isnull(b.equipment_type, ''))
			and isnull(b.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
		where a.company_id = @i_client_id
			and a.country_code = @i_country_code
			and a.call_category in ('PE')
			and a.call_status in ('O','A','I','QG')
			and isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
			and isnull(a.organogram_level_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.organogram_level_no, 0))
			and isnull(a.organogram_level_code, '') = isnull(@p_organogram_level_code, isnull(a.organogram_level_code, ''))
			and isnull(a.asset_in_warranty_ind, '') = isnull(@p_asset_status, isnull(a.asset_in_warranty_ind, ''))
			and isnull(a.call_mapped_to_employee_id,'') = isnull(@p_mapped_to_employee, isnull(a.call_mapped_to_employee_id, ''))
			and a.organogram_level_no = 4
			and a.equipment_id = ( case when @p_equipment_type = 'ZZZ' then 'ZZZ' else a.equipment_id end )
		
		if @p_detail_view = 'true'
		begin
  			select '' as o_report_info,
				'{' +
					'"call_ref_no":"' + call_ref_no + '",' +
					'"asset_id":"' + asset_id + '",' +
					'"call_status":"' + call_status + '",' +
					'"asset_status":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"equipment_id":"' + equipment_id + '",' +
					'"equipment_type":"' + equipment_type + '",' +
					'"comp_loc":"' + company_location_code + '",' +
					'"org_lvl_code":"' + org_lvl_code + '",' +
					'"lead_source":"' + lead_source + '"' +

				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsourcep
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			 and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
		end			
		else if @p_summary_by = 'company_location'	
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + company_location_code + '",' +
					'"summary_name":"' + company_location_code + '",' +
					'"series_by":"' + lead_source + '",' +
					'"series_name":"' + lead_source + '",' +
					'"count":"' + convert(varchar(10), round((convert(float, count(*))
					 / (select count(*) from #sales_projection_count_lead_leadsourcep where
						 company_location_code = a.company_location_code and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset()))  * 100), 2)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsourcep a
			where datepart(year, a.creation_date_time) = datepart(year, sysdatetimeoffset())
			group by company_location_code, lead_source		
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + org_lvl_code + '",' +
					'"summary_name":"' + org_lvl_code + '",' +
					'"series_by":"' + lead_source + '",' +
					'"series_name":"' + lead_source + '",' +
					'"count":"' + convert(varchar(5), round((convert(float, count(*)) 
					/ (select count(*) from #sales_projection_count_lead_leadsourcep where
						 org_lvl_code = a.org_lvl_code and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset()))  * 100), 2)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsourcep a
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by org_lvl_code,lead_source
		end
		else if @p_summary_by = 'asset_status'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"summary_name":"' + (
						case(asset_status)
							when 1 then 'In-Warranty'
							else 'Out of Warranty'
						end ) + '",' +
					'"series_by":"' + lead_source + '",' +
					'"series_name":"' + lead_source + '",' +
					'"count":"' + convert(varchar(5), round((convert(float, count(*)) 
					/ (select count(*) from #sales_projection_count_lead_leadsourcep where 
						asset_status = a.asset_status and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset()))  * 100), 2)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsourcep a
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by asset_status,lead_source
		end
		else if @p_summary_by = 'month_wise'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + case(datepart(month, creation_date_time))
							when 1 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jan' 
							when 2 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Feb' 
							when 3 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Mar' 
							when 4 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Apr' 
							when 5 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'May' 
							when 6 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jun' 
							when 7 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jul' 
							when 8 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Aug' 
							when 9 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Sep' 
							when 10 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Oct' 
							when 11 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Nov' 
							when 12 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Dec' 
						end + '",' +
					'"summary_name":"' + case(datepart(month, creation_date_time))
							when 1 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jan'
							when 2 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Feb'
							when 3 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Mar'
							when 4 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Apr'
							when 5 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'May'
							when 6 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jun'
							when 7 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Jul'
							when 8 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Aug'
							when 9 then  convert(nvarchar(4),datepart(year,creation_date_time)) + 'Sep'
							when 10 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Oct'
							when 11 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Nov'
							when 12 then convert(nvarchar(4),datepart(year,creation_date_time)) + 'Dec'
						end + '",' +
					'"series_by":"' + lead_source + '",' +
					'"series_name":"' + lead_source + '",' +
					'"count":"' + convert(varchar(5), round((convert(float, count(*)) 
					/ (select count(*) from #sales_projection_count_lead_leadsourcep where
						 creation_date_time = a.creation_date_time and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset()))  * 100), 2)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsourcep a
			where isnull(equipment_type, '') = isnull(@p_equipment_type, isnull(equipment_type, ''))
			group by datepart(month, creation_date_time), datepart(year, creation_date_time),lead_source
			order by datepart(year, creation_date_time) asc
		end
		else if @p_summary_by = 'equipment_type'
		begin
			select '' as o_report_info,
				'{' +
					'"summary_by":"' + equipment_type + '",' +
					'"summary_name":"' + equipment_type + '",' +
					'"series_by":"' + lead_source + '",' +
					'"series_name":"' + lead_source + '",' +
					'"count":"' + convert(varchar(5), round((convert(float, count(*)) 
					/ (select count(*) from #sales_projection_count_lead_leadsourcep where
					 equipment_type = a.equipment_type and datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset()))  * 100), 2)) + '"' +
				'}' as o_report_info_json
			from #sales_projection_count_lead_leadsourcep a
			where datepart(year, creation_date_time) = datepart(year, sysdatetimeoffset())
			group by equipment_type, lead_source
		end	
	end
	

	else if @p_report_info = 'machine_ageing_count'
	begin
		
		declare @p_ageing_period nvarchar (10)
		
		select @p_ageing_period = paramval from #input_params where paramname = 'ageing_period'
		
		create table #machine_ageing_count (
			ageing_period nvarchar(20),
			last_check_date datetimeoffset(7),
			org_lvl_no tinyint,
			org_lvl_code nvarchar(15),
			asset_id nvarchar(30),
			equipment_id nvarchar(30),
			equipment_category nvarchar(30),
			equipment_type nvarchar(60),
			company_location_code varchar(10),
			mapped_to_employee nvarchar (30),			
			asset_status nvarchar(30),
			customer_name nvarchar(150),
			contact_person_1_mobile_no varchar(30)				
		)
		
		insert #machine_ageing_count (
			ageing_period,
			last_check_date,
			org_lvl_no,
			org_lvl_code,
			asset_id,
			equipment_id,
			equipment_category,
			equipment_type,
			company_location_code,
			mapped_to_employee,			
			asset_status,
			customer_name,
			contact_person_1_mobile_no
		)	
		select ( case
				when datediff(dd,isnull(a.lastcheck_date, a.installation_date), sysdatetimeoffset()) <= 90 then 'Three Mo'
				when datediff(dd,isnull(a.lastcheck_date, a.installation_date), sysdatetimeoffset()) <= 180 then 'Six Mo'
				when datediff(dd,isnull(a.lastcheck_date, a.installation_date), sysdatetimeoffset()) <= 365 then 'One Yr'
				when datediff(dd,isnull(a.lastcheck_date, a.installation_date), sysdatetimeoffset()) <= 730 then 'One+ Yr'
				when datediff(dd,isnull(a.lastcheck_date, a.installation_date), sysdatetimeoffset()) <= 1095 then 'Two+ Yr'	
				else 'Three+ Yr'
			end	) , 
			a.lastcheck_date,
			a.servicing_org_level_no, 
			a.servicing_org_level_code, 
			a.asset_id, 
			a.equipment_id,
			b.equipment_category, 
			b.equipment_type, 
			(select top(1) company_location_code 
				from dealer_company_location_mapping d
				where d.company_id = @i_client_id
					and d.country_code = @i_country_code
					and d.dealer_id = a.servicing_org_level_code),
			(select top(1) employee_id 
				from dealer_mapping_to_employee e
				where e.company_id = @i_client_id
					and e.country_code = @i_country_code
					and e.mapping_purpose_code = 'OEMSEMAPPING'
					and e.dealer_id = a.servicing_org_level_code
					and (e.equipment_category = b.equipment_category or e.equipment_category = 'ALL')
					and (e.equipment_type = b.equipment_type or e.equipment_type = 'ALL') ),
			( 
				isnull((select 1 from asset_service_contract c
				where c.company_id = @i_client_id
				  and c.country_code = @i_country_code
				  and c.asset_id = a.asset_id
				  and c.contract_type = 'IW'
				  and sysdatetimeoffset() between c.effective_from_date and c.effective_to_date
				  ),0)
			),
			(select customer_name from customer c1
				where c1.company_id = @i_client_id
				 and c1.country_code = @i_country_code
				and c1.customer_id  = a.customer_id),
			(select contact_person_1_mobile_no from customer c2
				where c2.company_id = @i_client_id
				 and c2.country_code = @i_country_code
				and c2.customer_id  = a.customer_id)

			from asset_master a, equipment b
				where a.company_id = @i_client_id
					and a.country_code = @i_country_code
					and a.company_id = b.company_id
					and a.country_code = b.country_code 
					and a.installation_date is not NULL
					and a.equipment_id = b.equipment_id
					
				order by a.lastcheck_value 
				
			
		if @p_summary_by = 'company_location'	
		begin
			if @p_detail_view = 'true'
			begin
                select '' as o_report_info,
					'{' +
						'"ageing_period":"' + ageing_period + '",' +
						'"org_lvl_code":"' + isnull(org_lvl_code,'') + '",' +
						'"asset_id":"' + isnull(asset_id,'') + '",' +
						'"equipment_id":"' + isnull(equipment_id,'') + '",' +
						'"equipment_category":"' + isnull(equipment_category,'') + '",' +
						'"mapped_to_employee":"' + isnull(mapped_to_employee,'') + '",' +
						'"asset_status":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"customer_name":"' + isnull(customer_name,'') + '",' +
						'"contact_person_1_mobile_no":"' + isnull(contact_person_1_mobile_no,'') + '",' +
						'"comp_loc":"' + isnull(company_location_code,'') + '"' +
					'}' as o_report_info_json
				from #machine_ageing_count a
				where isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
					and isnull(a.org_lvl_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.org_lvl_no, 0))
					and isnull(a.org_lvl_code, '') = isnull(@p_organogram_level_code, isnull(a.org_lvl_code, ''))
					and isnull(a.asset_status, '') = isnull(@p_asset_status, isnull(a.asset_status, ''))
					and isnull(a.equipment_category, '') = isnull(@p_equipment_category, isnull(a.equipment_category, ''))
					and isnull(a.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
					and isnull(a.equipment_type, '') = isnull(@p_equipment_type, isnull(a.equipment_type, ''))
					and isnull(a.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
					and isnull(a.mapped_to_employee,'') = isnull(@p_mapped_to_employee, isnull(a.mapped_to_employee, ''))
					and isnull(a.ageing_period,'') = isnull(@p_ageing_period, isnull(a.ageing_period, ''))
					and a.company_location_code is not NULL
			end
			else
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + a.company_location_code + '",' +
						'"summary_name":"' + a.company_location_code + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
					'}' as o_report_info_json
				from #machine_ageing_count a
				where isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
					and isnull(a.org_lvl_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.org_lvl_no, 0))
					and isnull(a.org_lvl_code, '') = isnull(@p_organogram_level_code, isnull(a.org_lvl_code, ''))
					and isnull(a.asset_status, '') = isnull(@p_asset_status, isnull(a.asset_status, ''))
					and isnull(a.equipment_category, '') = isnull(@p_equipment_category, isnull(a.equipment_category, ''))
					and isnull(a.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
					and isnull(a.equipment_type, '') = isnull(@p_equipment_type, isnull(a.equipment_type, ''))
					and isnull(a.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
					and isnull(a.mapped_to_employee,'') = isnull(@p_mapped_to_employee, isnull(a.mapped_to_employee, ''))
					and isnull(a.ageing_period,'') = isnull(@p_ageing_period, isnull(a.ageing_period, ''))
					and a.company_location_code is not NULL
				group by a.company_location_code
			end
		end
		else if @p_summary_by = 'org_lvl_code'
		begin
			if @p_detail_view = 'true'
			begin
                select '' as o_report_info,
					'{' +
						'"ageing_period":"' + ageing_period + '",' +
						'"org_lvl_code":"' + isnull(org_lvl_code,'') + '",' +
						'"asset_id":"' + isnull(asset_id,'') + '",' +
						'"equipment_id":"' + isnull(equipment_id,'') + '",' +
						'"equipment_category":"' + isnull(equipment_category,'') + '",' +
						'"mapped_to_employee":"' + isnull(mapped_to_employee,'') + '",' +
												'"asset_status":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"customer_name":"' + isnull(customer_name,'') + '",' +
						'"contact_person_1_mobile_no":"' + isnull(contact_person_1_mobile_no,'') + '",' +
						'"comp_loc":"' + isnull(company_location_code,'') + '"' +
					'}' as o_report_info_json
				from #machine_ageing_count a
				where isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
					and isnull(a.org_lvl_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.org_lvl_no, 0))
					and isnull(a.org_lvl_code, '') = isnull(@p_organogram_level_code, isnull(a.org_lvl_code, ''))
					and isnull(a.asset_status, '') = isnull(@p_asset_status, isnull(a.asset_status, ''))
					and isnull(a.equipment_category, '') = isnull(@p_equipment_category, isnull(a.equipment_category, ''))
					and isnull(a.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
					and isnull(a.equipment_type, '') = isnull(@p_equipment_type, isnull(a.equipment_type, ''))
					and isnull(a.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
					and isnull(a.mapped_to_employee,'') = isnull(@p_mapped_to_employee, isnull(a.mapped_to_employee, ''))
					and isnull(a.ageing_period,'') = isnull(@p_ageing_period, isnull(a.ageing_period, ''))
					and a.company_location_code is not NULL
			end
			else
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + a.org_lvl_code + '",' +
						'"summary_name":"' + a.org_lvl_code + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
					'}' as o_report_info_json
				from #machine_ageing_count a
				where isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
					and isnull(a.org_lvl_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.org_lvl_no, 0))
					and isnull(a.org_lvl_code, '') = isnull(@p_organogram_level_code, isnull(a.org_lvl_code, ''))
					and isnull(a.asset_status, '') = isnull(@p_asset_status, isnull(a.asset_status, ''))
					and isnull(a.equipment_category, '') = isnull(@p_equipment_category, isnull(a.equipment_category, ''))
					and isnull(a.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
					and isnull(a.equipment_type, '') = isnull(@p_equipment_type, isnull(a.equipment_type, ''))
					and isnull(a.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
					and isnull(a.mapped_to_employee,'') = isnull(@p_mapped_to_employee, isnull(a.mapped_to_employee, ''))
					and isnull(a.ageing_period,'') = isnull(@p_ageing_period, isnull(a.ageing_period, ''))
				group by a.org_lvl_code
			end
		end
		else if @p_summary_by = 'asset_status'
		begin
			if @p_detail_view = 'true'
			begin
                select '' as o_report_info,
					'{' +
						'"ageing_period":"' + ageing_period + '",' +
						'"org_lvl_code":"' + isnull(org_lvl_code,'') + '",' +
						'"asset_id":"' + isnull(asset_id,'') + '",' +
						'"equipment_id":"' + isnull(equipment_id,'') + '",' +
						'"equipment_category":"' + isnull(equipment_category,'') + '",' +
						'"mapped_to_employee":"' + isnull(mapped_to_employee,'') + '",' +
						'"asset_status":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"customer_name":"' + isnull(customer_name,'') + '",' +
						'"contact_person_1_mobile_no":"' + isnull(contact_person_1_mobile_no,'') + '",' +
						'"comp_loc":"' + isnull(company_location_code,'') + '"' +
					'}' as o_report_info_json
				from #machine_ageing_count a
				where isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
					and isnull(a.org_lvl_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.org_lvl_no, 0))
					and isnull(a.org_lvl_code, '') = isnull(@p_organogram_level_code, isnull(a.org_lvl_code, ''))
					and isnull(a.asset_status, '') = isnull(@p_asset_status, isnull(a.asset_status, ''))
					and isnull(a.equipment_category, '') = isnull(@p_equipment_category, isnull(a.equipment_category, ''))
					and isnull(a.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
					and isnull(a.equipment_type, '') = isnull(@p_equipment_type, isnull(a.equipment_type, ''))
					and isnull(a.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
					and isnull(a.mapped_to_employee,'') = isnull(@p_mapped_to_employee, isnull(a.mapped_to_employee, ''))
					and isnull(a.ageing_period,'') = isnull(@p_ageing_period, isnull(a.ageing_period, ''))
					and a.company_location_code is not NULL
			end
			else
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + (
							case(a.asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"summary_name":"' + (
							case(a.asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
					'}' as o_report_info_json
				from #machine_ageing_count a
				where isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
					and isnull(a.org_lvl_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.org_lvl_no, 0))
					and isnull(a.org_lvl_code, '') = isnull(@p_organogram_level_code, isnull(a.org_lvl_code, ''))
					and isnull(a.asset_status, '') = isnull(@p_asset_status, isnull(a.asset_status, ''))
					and isnull(a.equipment_category, '') = isnull(@p_equipment_category, isnull(a.equipment_category, ''))
					and isnull(a.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
					and isnull(a.equipment_type, '') = isnull(@p_equipment_type, isnull(a.equipment_type, ''))
					and isnull(a.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
					and isnull(a.mapped_to_employee,'') = isnull(@p_mapped_to_employee, isnull(a.mapped_to_employee, ''))
					and isnull(a.ageing_period,'') = isnull(@p_ageing_period, isnull(a.ageing_period, ''))
				group by a.asset_status
			end
		end
		else if @p_summary_by = 'equipment_type'
		begin
			if @p_detail_view = 'true'
			begin
                select '' as o_report_info,
					'{' +
						'"ageing_period":"' + ageing_period + '",' +
						'"org_lvl_code":"' + isnull(org_lvl_code,'') + '",' +
						'"asset_id":"' + isnull(asset_id,'') + '",' +
						'"equipment_id":"' + isnull(equipment_id,'') + '",' +
						'"equipment_category":"' + isnull(equipment_category,'') + '",' +
						'"mapped_to_employee":"' + isnull(mapped_to_employee,'') + '",' +
						'"asset_status":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"customer_name":"' + isnull(customer_name,'') + '",' +
						'"contact_person_1_mobile_no":"' + isnull(contact_person_1_mobile_no,'') + '",' +
						'"comp_loc":"' + isnull(company_location_code,'') + '"' +
					'}' as o_report_info_json
				from #machine_ageing_count a
				where isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
					and isnull(a.org_lvl_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.org_lvl_no, 0))
					and isnull(a.org_lvl_code, '') = isnull(@p_organogram_level_code, isnull(a.org_lvl_code, ''))
					and isnull(a.asset_status, '') = isnull(@p_asset_status, isnull(a.asset_status, ''))
					and isnull(a.equipment_category, '') = isnull(@p_equipment_category, isnull(a.equipment_category, ''))
					and isnull(a.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
					and isnull(a.equipment_type, '') = isnull(@p_equipment_type, isnull(a.equipment_type, ''))
					and isnull(a.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
					and isnull(a.mapped_to_employee,'') = isnull(@p_mapped_to_employee, isnull(a.mapped_to_employee, ''))
					and isnull(a.ageing_period,'') = isnull(@p_ageing_period, isnull(a.ageing_period, ''))
					and a.company_location_code is not NULL
			end
			else
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + a.equipment_type + '",' +
						'"summary_name":"' + a.equipment_type + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
					'}' as o_report_info_json
				from #machine_ageing_count a
				where isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
					and isnull(a.org_lvl_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.org_lvl_no, 0))
					and isnull(a.org_lvl_code, '') = isnull(@p_organogram_level_code, isnull(a.org_lvl_code, ''))
					and isnull(a.asset_status, '') = isnull(@p_asset_status, isnull(a.asset_status, ''))
					and isnull(a.equipment_category, '') = isnull(@p_equipment_category, isnull(a.equipment_category, ''))
					and isnull(a.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
					and isnull(a.equipment_type, '') = isnull(@p_equipment_type, isnull(a.equipment_type, ''))
					and isnull(a.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
					and isnull(a.mapped_to_employee,'') = isnull(@p_mapped_to_employee, isnull(a.mapped_to_employee, ''))
					and isnull(a.ageing_period,'') = isnull(@p_ageing_period, isnull(a.ageing_period, ''))
				group by a.equipment_type
			end
		end
		else if @p_summary_by = 'ageing_period'
		begin
			if @p_detail_view = 'true'
			begin
                select '' as o_report_info,
					'{' +
						'"ageing_period":"' + ageing_period + '",' +
						'"org_lvl_code":"' + isnull(org_lvl_code,'') + '",' +
						'"asset_id":"' + isnull(asset_id,'') + '",' +
						'"equipment_id":"' + isnull(equipment_id,'') + '",' +
						'"equipment_category":"' + isnull(equipment_category,'') + '",' +
						'"mapped_to_employee":"' + isnull(mapped_to_employee,'') + '",' +
						'"asset_status":"' + (
							case(asset_status)
								when 1 then 'In-Warranty'
								else 'Out of Warranty'
							end ) + '",' +
						'"customer_name":"' + isnull(customer_name,'') + '",' +
						'"contact_person_1_mobile_no":"' + isnull(contact_person_1_mobile_no,'') + '",' +
						'"comp_loc":"' + isnull(company_location_code,'') + '"' +
					'}' as o_report_info_json
				from #machine_ageing_count a
				where isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
					and isnull(a.org_lvl_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.org_lvl_no, 0))
					and isnull(a.org_lvl_code, '') = isnull(@p_organogram_level_code, isnull(a.org_lvl_code, ''))
					and isnull(a.asset_status, '') = isnull(@p_asset_status, isnull(a.asset_status, ''))
					and isnull(a.equipment_category, '') = isnull(@p_equipment_category, isnull(a.equipment_category, ''))
					and isnull(a.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
					and isnull(a.equipment_type, '') = isnull(@p_equipment_type, isnull(a.equipment_type, ''))
					and isnull(a.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
					and isnull(a.mapped_to_employee,'') = isnull(@p_mapped_to_employee, isnull(a.mapped_to_employee, ''))
					and isnull(a.ageing_period,'') = isnull(@p_ageing_period, isnull(a.ageing_period, ''))
					and a.company_location_code is not NULL
			end
			else
			begin
				select '' as o_report_info,
					'{' +
						'"summary_by":"' + a.ageing_period + '",' +
						'"summary_name":"' + a.ageing_period + '",' +
						'"series_by":"' + '' + '",' +
						'"series_name":"' + '' + '",' +
						'"count":"' + convert(varchar(5), count(*)) + '"' +
					'}' as o_report_info_json
				from #machine_ageing_count a
				where isnull(a.company_location_code, '') = isnull(@p_company_location, isnull(a.company_location_code, ''))
					and isnull(a.org_lvl_no, 0) = isnull(convert(tinyint, @p_organogram_level_no), isnull(a.org_lvl_no, 0))
					and isnull(a.org_lvl_code, '') = isnull(@p_organogram_level_code, isnull(a.org_lvl_code, ''))
					and isnull(a.asset_status, '') = isnull(@p_asset_status, isnull(a.asset_status, ''))
					and isnull(a.equipment_category, '') = isnull(@p_equipment_category, isnull(a.equipment_category, ''))
					and isnull(a.equipment_category,'') in ( select equipment_category from #report_equipment_categories_applicable)
					and isnull(a.equipment_type, '') = isnull(@p_equipment_type, isnull(a.equipment_type, ''))
					and isnull(a.equipment_type,'') in ( select equipment_type from #report_equipment_types_applicable)
					and isnull(a.mapped_to_employee,'') = isnull(@p_mapped_to_employee, isnull(a.mapped_to_employee, ''))
					and isnull(a.ageing_period,'') = isnull(@p_ageing_period, isnull(a.ageing_period, ''))
				group by a.ageing_period
				order by case when a.ageing_period = 'Three Mo' then '1'
							 when a.ageing_period = 'Six Mo' then '2'
							 when a.ageing_period = 'One Yr' then '3'
							 when a.ageing_period = 'One+ Yr' then '4'
							 when a.ageing_period = 'Two+ Yr' then '5'
							 when a.ageing_period = 'Three+ Yr' then '6'
						 else a.ageing_period end asc		  
			end
		end
	end
	SET NOCOUNT OFF;
END


