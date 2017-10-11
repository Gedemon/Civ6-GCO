/* Link text entries to Buildings, Units, ... */

UPDATE Buildings SET Description 	= 	(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Buildings.BuildingType || '_DESCRIPTION' = Tag AND Language='en_US')
			WHERE EXISTS	   			(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Buildings.BuildingType || '_DESCRIPTION' = Tag AND Language='en_US');
			
UPDATE Buildings SET Name 			= 	(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Buildings.BuildingType || '_NAME' = Tag AND Language='en_US')
			WHERE EXISTS	   			(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Buildings.BuildingType || '_NAME' = Tag AND Language='en_US');