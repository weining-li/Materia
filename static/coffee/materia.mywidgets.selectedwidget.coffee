# Handles the widget currently selected (on the big screeny thing)
# TODO: needs some serious refactoring to reduce complexity of large methods
Namespace('Materia.MyWidgets').SelectedWidget = do ->
	STORAGE_TABLE_MAX_ROWS_SHOWN = 100
	selectedWidgetInstId = 0
	scoreSummaries = {}
	semesterPlayLogs = {}
	storageData = {}
	selectedData = null
	dateRanges = null

	# Initializes the gateway for the api
	# @string path to gateway
	init = (gateway) ->
		$('.show-older-scores-button').click (e) ->
			e.preventDefault()
			Materia.MyWidgets.SelectedWidget.showAllScores()


	getSelectedId = ->
		selectedWidgetInstId

	setSelected = (inst_id) ->
		if $('.page').is ':visible' and not $('section .error').is ':visible'
			Materia.Set.Throbber.startSpin '.page'

		selectedWidgetInstId = inst_id
		$('.gameSelected').removeClass 'gameSelected'
		$('#widget_' + selectedWidgetInstId).addClass 'gameSelected'

		Materia.MyWidgets.Statistics.clearGraphs()

		populateDisplay()

	getCurrentSemester = ->
		return selectedData.year+' '+selectedData.term

	populateAttempts = (attemptsAllowed) ->
		attemptsAllowed = parseInt attemptsAllowed, 10
		$('#attempts').html(if attemptsAllowed > 0 then attemptsAllowed else 'Unlimited')

	populateAvailability = (startDateInt, endDateInt) ->
		if $('section.directions').is(':visible')
			$('section.directions').hide()
			$('section.page').show()

		availability = Materia.Set.Availability.get(startDateInt, endDateInt)

		$availability = $('#avaliability')

		if endDateInt < 0 && startDateInt < 0
			$availability.removeAttr('data-type')
			$availability.html('Anytime')
		else if startDateInt < 0 && endDateInt > 0
			$availability.attr('data-type', 'endDateOnly')
			$availability.html('Open until <span class="available_date">'+availability.end.date+'</span> at <span class="available_time">'+availability.end.time+'</span>')
		else if startDateInt > 0 && endDateInt < 0
			start = new Date(startDateInt)
			$availability.attr('data-type', 'startDateOnly')
			$availability.html('Anytime after <span class="available_date">'+availability.start.date+'</span> at <span class="available_time">'+availability.start.time+'</span>')
		else
			start = new Date(startDateInt)
			end = new Date(endDateInt)
			$availability.removeAttr('data-type')
			$availability.html('From <span class="available_date">'+availability.start.date+'</span> at <span class="available_time">'+availability.start.time+'</span> until <span class="available_date">'+availability.end.date+'</span> at <span class="available_time">'+availability.end.time+'</span>')

	# Displays a no-access message when attempting to access a widget without sharing permissions.
	noAccess = ->
		$('section.page').children().hide()

		if($('section.directions').is(':visible'))
			$('section.directions').hide()
			$('section.page').show()

		#  put the error template on screen
		$('section.page').append($('#t-error').html())

	# Shows selected game information on the mainscreen.
	# @param   element   The element that was clicked ($('.widget_list').children('div'))
	populateDisplay = ->
		count = null
		widgetID = null

		if $('section .error').is(':visible') then $('section .error').remove()

		Materia.Coms.Json.send 'session_valid', ['basic_author'], (data) ->
			loadDateRanges ->
				Materia.Widget.getWidget selectedWidgetInstId, (inst) ->
					clean_name = widgetName = inst.clean_name
					widgetID = inst.widget.id
					$editButton = $('#edit_button')

					# Gets current user
					Materia.User.getCurrentUser (user) ->
						# Gets who is currently using this widget (i.e. sharing)
						Materia.Coms.Json.send 'permissions_get', [0, inst.id], (perms) ->
							user_perms = perms['user_perms']
							widget_user_perms = perms['widget_user_perms']

							accessLevel = 0
							if(typeof user_perms[user.id] != 'undefined' && typeof user_perms[user.id][0] != 'undefined')
								accessLevel = Number(user_perms[user.id][0])

							# disable certain interactions if the user's access is view-only or widget isn't editable
							if(accessLevel == 0)
								$editButton.unbind()
								$editButton.attr('href','#')
								$editButton.click -> return false
								$editButton.addClass('disabled')

								$('.copy').addClass('disabled')
								$('#copy_widget_link').addClass('disabled')
								$('#delete_widget_link').addClass('disabled').parent().addClass('disabled')
							else
								if Number(inst.widget.is_editable) == 1
									$editButton.removeClass('disabled')
								else
									$editButton.unbind()
									$editButton.attr('href','#')
									$editButton.click -> return false
									$editButton.addClass('disabled')

								$('.copy').removeClass('disabled')
								$('#copy_widget_link').removeClass('disabled')
								$('#delete_widget_link').removeClass('disabled').parent().removeClass('disabled')

							if accessLevel == 0 || inst.is_draft == true
								# CSS to disable additional options needs to be re-worked
								$('.attempts_parent').addClass('disabled')
								$('#edit-avaliability-button').addClass('disabled')
								$('#attempts').addClass('disabled')
								$('#avaliability').addClass('disabled')
							else
								$('.attempts_parent').removeClass('disabled')
								$('.copy').removeClass('disabled')
								$('#copy_widget_link').removeClass('disabled')
								$('#copy_widget_link').unbind('click')
								$('#delete_widget_link').removeClass('disabled')
								$('#delete_widget_link').unbind('click')
								$('#edit-avaliability-button').removeClass('disabled')
								$('#attempts').removeClass('disabled')
								$('#avaliability').removeClass('disabled')

							$('#edit-avaliability-button').unbind('click')
							$('#attempts').unbind('click')
							$('#avaliability').unbind('click')
							jqmodalOptions =
								modal            : true,
								backgroundStyle  : 'light',
								className        : 'availability',
								html             : $('#t-availibility').html(),
								closingSelectors : ['.cancel_button']

							$('#edit-avaliability-button').not('.disabled').jqmodal(jqmodalOptions, Materia.MyWidgets.Availability.popup)
							$('#attempts').not('.disabled').jqmodal(jqmodalOptions, Materia.MyWidgets.Availability.popup)
							$('#avaliability').not('.disabled').jqmodal(jqmodalOptions, Materia.MyWidgets.Availability.popup)

							$('.copy').unbind('click')
							$('.copy.disabled').click -> return false
							$('.copy').not('.disabled').jqmodal
								modal            : true,
								backgroundStyle  : 'light',
								className        : 'copy',
								html             : $('#t-copy-popup').html(),
								closingSelectors : ['.cancel_button']
							, ->
								$('#popup.copy input').focus()

								newTitle = $('#popup.copy input.newtitle').val()

								$('#popup.copy input.newtitle').keypress (e) ->
									if e.which == 10 or e.which == 13
										copyWidget()

								$('#popup.copy .copy_button').click (e) ->
									e.preventDefault()
									copyWidget()
							$('.delete_dialogue').hide()
							$('.additional_options').fadeIn('fast')

							$('.delete').unbind('click')
							$('.delete.disabled').click -> return false
							$('.delete').not('.disabled').toggle ->
								$('.additional_options').hide()
								$('.delete_dialogue').fadeIn('fast')
								$('.delete_dialogue').show()
							, ->
								$('.delete_dialogue').hide()
								$('.additional_options').fadeIn('fast')

							# count up the number of other users collaboratin
							count = 0
							for id of widget_user_perms
								if id != user.id then count++

							str = 'Collaborate'
							str += ' ('+count+')' if count > 0
							$('#share_widget_link').text(str)

					populateAvailability(inst.open_at, inst.close_at)
					populateAttempts(inst.attempts)

					$('.page hgroup h1').html(inst.name)
					$('.page hgroup h3').html(inst.widget.name)

					$('.overview .icon').attr('src', Materia.Image.iconUrl(inst.widget.dir, 275))

					if BEARD_MODE? and BEARD_MODE == true

						$('.widget .icon').each (index) ->
							rand = Math.floor((Math.random()*beards.length)+1) - 1

							$(this).addClass('small_'+beards[rand])

							if ($(this).parent().hasClass('gameSelected'))
								$('.icon_container').addClass('med_'+beards[rand])

						existing = $('.overview .icon_container').attr('class').split(' ')

						for e in existing
							if e != 'icon_container' && e != 'big_bearded'
								$('.overview .icon_container').removeClass(e)

						beardType = $('.widget.gameSelected .icon').attr('class').split(' ')[2]
						beardType = 'med'+beardType.substring(5)

						$('.widget .icon').addClass('bearded')
						$('.icon_container')
							.addClass('big_bearded')
							.addClass(beardType)

					if($('.page').is(':hidden'))
						$('.page').show()
					else
						$('.page').children().show()

					$('#preview_button').attr('href','/preview/'+selectedWidgetInstId+'/'+inst.clean_name).click ->
						return false if $(this).hasClass('disabled')

					#  Bind the edit button
					$editButton.attr('href', BASE_URL + 'edit/'+selectedWidgetInstId+'/'+inst.clean_name)
					$editButton.unbind('click')

					# update display if not playable
					if inst.is_draft or inst.widget.is_playable == 0
						$('.share-widget-container')
							.addClass('draft')
							.fadeTo('fast', 0.3)
							.children('h3')
							.html('Publish to share with your students')

						$('#play_link').attr('disabled', 'disabled')

						$editButton.click ->
							Materia.Coms.Json.send 'widget_instance_lock',[selectedWidgetInstId], (success) ->
								if success
									window.location = $editButton.attr('href')
								else
									alert('This widget is currently locked you will be able to edit this widget when it is no longer being edited by somebody else.')
									
							return false
					# update display if playable
					# TODO: this case should probably be combined with the is not a draft case below?
					else
						$('.share-widget-container')
							.removeClass('draft')
							.fadeTo('fast', 1)
							.children('h3')
							.html('Share with your students')

						$('#play_link')
							.unbind('click')
							.val(BASE_URL + 'play/'+String(selectedWidgetInstId)+'/'+inst.clean_name)
							.click(->$(this).select())

						$('#embed_link')
							.unbind('click')
							.val(getEmbedLink(inst))
							.click(->$(this).select())

						$('.share-widget-container input').removeAttr('disabled')

						$editButton.jqmodal
							modal            : true,
							backgroundStyle  : 'light',
							className        : 'edit-published-widget',
							html             : $('#t-edit-widget-published').html(),
							closingSelectors : ['.cancel_button']
						, ->
							$('.edit-published-widget .action_button').attr('href', $editButton.attr('href'))

					# TODO: this case should probably be combined with the else case above?
					if !inst.widget.is_draft
						$('.my_widgets .page .scores').show()
						$('.my_widgets .page .embed').show()

						$('.my_widgets .page .scores').hide() if !inst.widget.is_scorable
						$('#play_link').val(BASE_URL + 'play/'+String(selectedWidgetInstId)+'/'+inst.clean_name)
						$('#embed_link').val(getEmbedLink(inst))

						$('#embed_link').hide()
						$('.share-widget-container span').unbind('click')
						$('.share-widget-container span').click (e) ->
							e.preventDefault
							$('#embed_link').slideToggle 'fast'

						toggleShareWidgetContainer('close')
						$('.container').fadeIn() if $('.container:hidden').length > 0

						#  reset scores & data ui:
						$scoreWrapper = $('.scoreWrapper')
						$scoreWrapper.slice(1).remove() if $scoreWrapper.length > 1

						$('.show-older-scores-button').hide()
						$('.chart').attr('id', '').empty()

						getScoreSummaries selectedWidgetInstId, (data) ->
							$('#export_scores_button').unbind()
							$exportScoresButton = $('#export_scores_button')

							#  no data
							if data.list.length == 0
								$exportScoresButton.addClass('disabled')
								$('.noScores').show()
								$scoreWrapper.hide()
							else
								$('.noScores').hide()
								populateScoreWrapper($scoreWrapper, data.last)
								if(data.list.length > 1)
									$('.show-older-scores-button').show()

								hasScores = false
								for d in data.list
									if d.distribution?
										hasScores = true
										break

								if hasScores
									$exportScoresButton.removeClass('disabled')
								else
									$exportScoresButton.addClass('disabled')
								$('#export_scores_button:not(".disabled")').jqmodal
									modal            : true,
									className        : 'csv_popup',
									html             : $('#t-csv').html(),
									closingSelectors : ['.cancel','.download']
								, ->
									Materia.MyWidgets.Csv.buildPopup()
					else
						$('.my_widgets .page .scores').hide()
						$('.my_widgets .page .embed').hide()

					if inst.widget.is_playable == 0
						$('#preview_button').addClass('disabled')
						$('.arrow_right').addClass('disabled')
					else
						$('#preview_button').removeClass('disabled')
						$('.arrow_right').removeClass('disabled')

					Materia.Set.Throbber.stopSpin('.page')

	copyWidget = () ->
		$('#popup.copy .copy_error').hide()
		field = $('#popup.copy input.newtitle')

		if (field.val().length > 0 && field.val() != newTitle)
			inst_id = $('.gameSelected').attr('id').split('_')[1]

			Materia.MyWidgets.Tasks.copyWidget(inst_id, field.val())
			$('#popup.copy .cancel_button').click()
		else
			$('#popup.copy .copy_error').css('display', 'block')
			newTitle = field.val()
			#  throw some sort of validation error
			#

	getEmbedLink = (inst) ->
		width = if String(inst.widget.width) != '0' then  inst.widget.width else 800
		height = if String(inst.widget.height) != '0' then inst.widget.height else 600
		draft = if inst.is_draft then "#{inst.widget.name} Widget" else inst.name
		"<iframe src='#{BASE_URL}embed/#{selectedWidgetInstId}/#{inst.clean_name}' width='#{width}' height='#{height}' style='margin:0;padding:0;border:0;'><a href='#{BASE_URL}play/#{selectedWidgetInstId}/#{inst.clean_name}'>#{draft}</a></iframe>"

	loadDateRanges = (callback) ->
		unless dateRanges?
			Materia.Coms.Json.send 'semester_date_ranges_get', [], (data) ->
				dateRanges = data
				callback()
		else
			callback()

	toggleShareWidgetContainer = (state) ->
		$shareWidgetContainer = $('.share-widget-container')

		unless state?
			state = $shareWidgetContainer.hasClass('closed') ? 'open' : 'close'

		if state == 'open'
			$shareWidgetContainer.switchClass('closed', '', 200)
		else if state == 'close'
			$shareWidgetContainer.switchClass('', 'closed', 200)

	populateScoreWrapper = ($scoreWrapper, data) ->
		$scoreWrapper.attr('data-semester', data.id)
		$scoreWrapper.attr('data-semester-str', createSemesterString(data))
		$scoreWrapper.find('.view').html(data.term+' '+data.year)

		#  no scores, but we do have storage data
		if typeof data.distribution == 'undefined' && typeof data.storage != 'undefined'
			$scoreWrapper.show()

			$scoreWrapper.find('li:nth-child(1) a').hide()
			$scoreWrapper.find('li:nth-child(2) a').hide()
			$scoreWrapper.find('li:nth-child(3) a').show()

			setScoreView(data.id, 'data')
		else #  has scores, might have storage data
			$scoreWrapper.show()

			$scoreWrapper.find('li:nth-child(1) a').show()
			$scoreWrapper.find('li:nth-child(2) a').show()

			if typeof data.storage == 'undefined'
				$scoreWrapper.find('li:nth-child(3) a').hide()
			else
				$scoreWrapper.find('li:nth-child(3) a').show()

			$scoreWrapper.find('.chart').attr('id', 'chart_' + data.id)

			setScoreView(data.id, 'graph')

	processDataIntoSemesters = (logs, getTimestampFunction) ->
		semesters = {}
		timestamp = null

		$.each logs, (i, log) ->
			timestamp = getTimestampFunction(log)
			logMeta = getSemesterFromTimestamp(timestamp)
			semesterString = logMeta.year + ' ' + logMeta.semester.toLowerCase()

			if(!semesters[semesterString])
				semesters[semesterString] = []
			semesters[semesterString].push(log)
		return semesters

	getSemesterFromTimestamp = (timestamp) ->
		for range in dateRanges
			return range if timestamp >= parseInt(range.start, 10) && timestamp <= parseInt(range.end, 10)
		return undefined

	#  storage data doesn't really enforce a schema.
	#  this function determines every field used throughout the
	#  storage data and then applies that schema to each item.
	normalizeStorageDataColumns = (rows) ->
		#  go through all the rows and collect the fields used:
		curRow
		fields = {}
		for r in rows
			curRow = r.data
			for j in curRow
				if typeof j == 'undefined'
					j = null

		#  now go through each row again and add in the missing fields
		for r in rows
			r.data = $.extend({}, fields, r.data)

		rows

	setScoreView = (semester, newScoreView) ->
		$scoreWrapper = $('.scoreWrapper[data-semester="' + semester + '"]')
		$scoreWrapper.attr('data-score-view', newScoreView)

		$scoreWrapper.find('.choices li.scoreTypeSelected').removeClass('scoreTypeSelected')
		$scoreWrapper.find('.display.table').hide()
		$scoreWrapper.find('.display.graph').hide()
		$scoreWrapper.find('.display.data').hide()

		switch newScoreView
			when 'graph'
				$scoreWrapper.find('.display.graph').show()
				$scoreWrapper.find('.choices li:first-child').addClass('scoreTypeSelected')
				$scoreWrapper.find('.numeric li').show()
			when 'table'
				$scoreWrapper.find('.display.table').show()
				$scoreWrapper.find('.choices li:nth-child(2)').addClass('scoreTypeSelected')
				$scoreWrapper.find('.numeric li').show()
			when 'data'
				$scoreWrapper.find('.display.data').show()
				$scoreWrapper.find('.choices li:nth-child(3)').addClass('scoreTypeSelected')
				$scoreWrapper.find('.numeric li').hide()

		updateSemesterScores(semester)

	updateSemesterScores = (semester) ->
		$scoreWrapper = $('.scoreWrapper[data-semester="' + semester + '"]')
		scoreView = $scoreWrapper.attr('data-score-view')

		switch scoreView
			when 'table' then updateTable($scoreWrapper)
			when 'data' then updateData($scoreWrapper)
			else
				updateGraph($scoreWrapper)

		updateSummary(semester)

	getScoreSummaries = (inst_id, callback) ->
		#  if we didn't already get this data, get it now
		if typeof scoreSummaries[inst_id] == 'undefined'
			Materia.Coms.Json.send 'score_summary_get', [inst_id, true], (data) ->
				if(data != null && data.length > 0)
					o = {}
					last = data[0].id
					for d in data
						o[d.id] = d
					#  we more conviently store the data in an array (list) and an object (map).
					#  list is an ordered list of summary data by semesters (in descending order).
					#  map is an object where the semester_id (database semester code) is the key.
					scoreSummaries[inst_id] = {list:data, map:o, last:data[0]}
					# scoreSummaries[inst_id] = data
				else
					scoreSummaries[inst_id] = {list:[], map:{}, last:undefined}
				callback(scoreSummaries[inst_id])
		else
			callback(scoreSummaries[inst_id])

	getPlayLogs = (inst_id, semester, year, callback) ->
		# key our logs off of semester+year+instanceID
		logKey = "#{semester}_#{year}_#{inst_id}"
		# If we haven't loaded them yet, load em
		unless semesterPlayLogs[logKey]?
			Materia.Coms.Json.send 'play_logs_get', [inst_id, semester, year], (logs) ->
				semesterPlayLogs[logKey] = processDataIntoSemesters(logs, (o) -> return o.time)
				callback semesterPlayLogs[logKey]
		else
			callback semesterPlayLogs[logKey]

	getStorageData = (inst_id, callback) ->
		if typeof storageData[inst_id] == 'undefined'
			Materia.Coms.Json.send 'play_storage_get', [inst_id], (data) ->
				storageData[inst_id] = {}
				temp = {}
				getPlayTime = (o) -> return o.play.time
				#table
				#semester

				for tableName, tableData of data
					temp[tableName] = processDataIntoSemesters(tableData, getPlayTime)
				for tableName, semestersData of temp
					for semesterId, semesterData of semestersData
						if typeof storageData[inst_id][semesterId] == 'undefined'
							storageData[inst_id][semesterId] = {}
						if semesterData.length > STORAGE_TABLE_MAX_ROWS_SHOWN
							storageData[inst_id][semesterId][tableName] = {truncated:true, total:semesterData.length, data:semesterData.slice(0, STORAGE_TABLE_MAX_ROWS_SHOWN)}
						else
							storageData[inst_id][semesterId][tableName] = {truncated:false, data:semesterData}

						storageData[inst_id][semesterId][tableName].data = normalizeStorageDataColumns(storageData[inst_id][semesterId][tableName].data)

				callback(storageData[inst_id])
		else
			callback(storageData[inst_id])

	updateSummary = (semester) ->
		getScoreSummaries selectedWidgetInstId, (data) ->
			semesterData = data.map[semester]
			$scoreWrapper = $('.scoreWrapper[data-semester="' + semester + '"]')
			plays = 0

			if semesterData.students?
				$scoreWrapper.find('.players').html(semesterData.students)
			if semesterData.average?
				$scoreWrapper.find('.final-average').html(semesterData.average)

			if semesterData.distribution?
				plays += dis for dis in semesterData.distribution
				$scoreWrapper.find('.score-count').html(plays)

	updateGraph = ($scoreWrapper) ->
		semester = $scoreWrapper.attr('data-semester')
		Materia.Set.Throbber.startSpin('.scoreWrapper[data-semester="' + semester + '"]"')

		getScoreSummaries selectedWidgetInstId, (data) ->
			Materia.Set.Throbber.stopSpin('.scoreWrapper[data-semester="' + semester + '"]"')
			brackets = data.map[semester].distribution
			Materia.MyWidgets.Statistics.createGraph('chart_' + semester, brackets)

	updateTable = ($scoreWrapper) ->
		semester = $scoreWrapper.attr('data-semester')
		semesterStr = $scoreWrapper.attr('data-semester-str')

		Materia.Set.Throbber.startSpin('.scoreWrapper[data-semester="' + semester + '"] .display.table')
		getPlayLogs selectedWidgetInstId, semesterStr.split('_')[1], semesterStr.split('_')[0], (logsBySemester) ->
			$table = $scoreWrapper.find('.display.table')
			tableSort = $table.attr('data-sort')
			Materia.MyWidgets.Statistics.createTable($table, logsBySemester[semesterStr.replace('_', ' ')], tableSort, selectedWidgetInstId)
			Materia.Set.Throbber.stopSpin('.scoreWrapper[data-semester="' + semester + '"] .display.table')

	updateData = ($scoreWrapper) ->
		semester = $scoreWrapper.attr('data-semester')
		semesterStr = $scoreWrapper.attr('data-semester-str')
		Materia.Set.Throbber.startSpin('.scoreWrapper[data-semester="' + semester + '"] .data')
		getStorageData selectedWidgetInstId, (data) ->
			createStorageDataTables(data[semesterStr.replace('_', ' ')], $scoreWrapper.find('.display.data'))
			Materia.Set.Throbber.stopSpin('.scoreWrapper[data-semester="' + semester + '"] .data')

	createStorageDataTables = (tables, $element) ->
		$element.empty()

		tableNames = []
		$label = $('<div class="table-label"><h4>Table:</h4></div>')
		$select = null

		tableNames.push(tableName) for tableName, tableData of tables

		if tableNames.length == 1
			$label.append('<span>' + tableNames[0] + '</span>')
		else
			$select = $('<select></select>')
			for name in tableNames
				$select.append('<option value="'+name+'">'+name+'</option>')

			$select.change (event) ->
				semester = $(event.target).parents('.scoreWrapper').attr('data-semester-str')
				selectedTableName = $(event.target).find(':selected').val()
				getStorageData selectedWidgetInstId, (data) ->
					createStorageDataTable(data[semester.toLowerCase().replace('_', ' ')][selectedTableName], $element)
			$label.append($select)

		$element.append($label)
		$element.prepend('<a class="storage">Download Table</a>')

		$('.storage').click (event) ->
			event.preventDefault()

			$scoreWrapper = $(event.target).parents('.scoreWrapper')
			$tableLabel = $scoreWrapper.find('.table-label')
			table = ''
			if($tableLabel.find('select').length > 0)
				table = $tableLabel.find('select').val()
			else
				table = $tableLabel.find('span').text()
			if table != ''
				semester = $scoreWrapper.attr('data-semester-str').replace('_', '-')
				window.location = '/scores/storage/' + selectedWidgetInstId + '/' + table + '/' + semester
		createStorageDataTable(tables[tableNames[0]], $element)

	createStorageDataTable = (tableObject, $element) ->
		$element.find('.dataTables_wrapper').remove()

		$element.find('.truncated-table').remove()
		if(tableObject.truncated)
			$element.append('<p class="truncated-table">Showing only the first ' + STORAGE_TABLE_MAX_ROWS_SHOWN + ' entries of this table. Download the table to see all ' + tableObject.total.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',') + ' entries.</p>')

		rows = tableObject.data

		if(rows.length > 0)
			$table = $('<table></table>')
			$headers = $('<tr><th>user</th><th>firstName</th><th>lastName</th><th>time</th></tr>')
			$tbody = $('<tbody></tbody>')
			$curTr
			nullValue
			len = rows.length

			$headers.append('<th>' + rowName + '</th>') for rowName, rowData of rows[0].data

			$headers.wrap('<thead>')
			$table.append($headers.parent())

			for row in rows
				$curTr = $('<tr><td>'+row.play.user+'</td><td>'+row.play.firstName+'</td><td>'+row.play.lastName+'</td><td>'+row.play.time+'</td></tr>')
				for fieldName, fieldData of row.data
					nullValue = fieldData == null
					if nullValue
						fieldData = '--'

					$curTr.append('<td'+( if nullValue then ' class="null"' else '')+'>'+fieldData+'</td>')

				$tbody.append($curTr)

			$table.append($tbody)
			$element.append($table)
			$table.dataTable
				sScrollX: '100%'

	toggleTableSort = (semester) ->
		$scoreWrapper = $('.scoreWrapper[data-semester="' + semester + '"]')
		$table = $scoreWrapper.find('.display.table')
		tableSort = $table.attr('data-sort')

		if ($(this).hasClass('up'))
			$(this).removeClass('up').addClass('down')
		else if ($(this).hasClass('down'))
			$(this).removeClass('down').addClass('up')

		$table.attr('data-sort', if tableSort == 'desc' then 'asc' else 'desc')
		updateTable($scoreWrapper)

	showAllScores = ->
		getScoreSummaries selectedWidgetInstId, (data) ->
			$semester = $('.scoreWrapper')
			$scores = $('.scores')

			$('.show-older-scores-button').hide()

			for i in [1..data.list.length-1]
				$clone = $semester.clone()
				$scores.append($clone)
				populateScoreWrapper($clone, data.list[i])

	createSemesterString = (o) ->
		return (o.year + '_' + o.term).toLowerCase()

	noWidgets = ->
		$('section.page').hide()

		rightSide = $('section.directions')
		rightSide.show()
		rightSide.children('h1').html('You have no widgets!')
		rightSide.children('p').html('Make a new widget in the widget catalog.')

		$('body').append('<div class="qtip top nowidgets">Click here to start making a new widget!</div>')

	init						: init
	noAccess					: noAccess
	populateAvailability		: populateAvailability
	populateAttempts			: populateAttempts
	setSelected					: setSelected
	getCurrentSemester			: getCurrentSemester
	setScoreView				: setScoreView
	toggleTableSort				: toggleTableSort
	showAllScores				: showAllScores
	toggleShareWidgetContainer	: toggleShareWidgetContainer
	selectedWidgetInstId		: selectedWidgetInstId
	noWidgets					: noWidgets
	getSelectedId:getSelectedId
