<cfcomponent extends="Sql" output="false">

	<cffunction name="visit_relation" returntype="any" access="private" hint="Generate SQL for a relation specific to SqlServer">
		<cfargument name="obj" type="any" required="true" />
		<cfscript>
			var loc = {};
			
			// see if limits or offsets exist
			loc.limit = StructKeyExists(obj.sql, "limit");
			loc.offset = StructKeyExists(obj.sql, "offset");
			
			// if limit is found
			if (loc.limit) {
				
				// duplicate relation to keep old one intact
				obj = obj.clone();
				
				// use ROW_NUMBER() in a sub-query to accomplish pagination
				if (loc.offset) {
					
					// calculate row number range
					loc.start = obj.sql.offset + 1;
					loc.end = obj.sql.offset + obj.sql.limit;
					
					// throw error if there is no ORDER BY
					if (ArrayLen(obj.sql.orders) EQ 0)
						throwException("ORDER BY clause is required for pagination");
					
					// force a GROUP BY if trying to get DISTINCT rows in subquery
					if (ArrayContains(obj.sql.selectFlags, "DISTINCT") AND ArrayLen(obj.sql.groups) EQ 0)
						obj.sql.groups = Duplicate(obj.sql.select);
					
					// create new SELECT item from inner query
					variables.aliasOff = true;
					ArrayAppend(obj.sql.select, sqlLiteral("ROW_NUMBER() OVER (ORDER BY #ArrayToList(visit(obj.sql.orders), ', ')#) AS [rowNum]"));
					variables.aliasOff = false;
					
					// wipe out ORDER BY in inner query
					obj.sql.orders = [];
					
					// remove LIMIT and OFFSET from inner query
					StructDelete(obj.sql, "limit");
					StructDelete(obj.sql, "offset");
					
					// get SQL for inner query and return inside of SELECT
					return "SELECT * FROM (#super.visit_relation(obj)#) [paged_query] WHERE [rowNum] BETWEEN #loc.start# AND #loc.end# ORDER BY [rowNum] ASC";
				
				// use TOP to restrict dataset instead of LIMIT
				} else {
					ArrayAppend(obj.sql.selectFlags, "TOP #obj.sql.limit#");
					StructDelete(obj.sql, "limit");
				}
			
			// if only offset is found
			} else if (loc.offset) {
				throwException("OFFSET not supported in Microsoft SQL Server");
			}
			
			return super.visit_relation(obj);
		</cfscript>
	</cffunction>
	
	<cffunction name="_escapeSqlEntity" returntype="string" access="private"  hint="Escape SQL column and table names">
		<cfargument name="subject" type="string" required="true" />
		<cfscript>
			var loc = {};
			loc.reg = "[^ \t'.,\]\[\(\)]+";
			if (REFind("^(#loc.reg#)(\.#loc.reg#)*$", arguments.subject) EQ 0)
				return arguments.subject;
			loc.subject = REReplace(arguments.subject, "^(#loc.reg#)", "[\1]");
			loc.subject = REReplace(loc.subject, "\.(#loc.reg#)", ".[\1]", "ALL");
			return loc.subject;
		</cfscript>
	</cffunction>
</cfcomponent>