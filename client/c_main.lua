--[[
	Full Name:	Editor for thisdp's graphical user interface system
	Short Name: DGS Editor
	Language:	Lua
	Platform:	MTASA
	Author:		thisdp
	License: 	DPL v1 (The same as DGS)
	State:		OpenSourced
	Note:		This script uses the OOP syntax of DGS
]]

dgsEditor = {}
historyActionState = 0 -- state history
dgsEditor.ActionHistory = {
	Undo = {},
	Redo = {}
}
dgsEditor.Action = {}
dgsEditor.ActionFunctions = {
    destroy = function(action)
		local element = unpack(action.arguments)
		if element then
			return dgsEditorDestroyElement(element)
		end
    end,
    show = function(action)
		local element = unpack(action.arguments)
		if element then
			element.visible = true
			element.isCreatedByEditor = true
			if element.children then
				for _, child in pairs(element.children) do
					--if it is not an internal element
					if child.isCreatedByEditor then
						child.isCreatedByEditor = true
					end
				end
			end
			return true
		end
    end,
	cancelProperty = function(action)
		local element,property,newValue,oldValue = unpack(action.arguments)
		element[property] = oldValue
		local tempPropertyList = element.dgsEditorPropertyList
		if not tempPropertyList then tempPropertyList = {} end
		tempPropertyList[property] = oldValue
		element.dgsEditorPropertyList = tempPropertyList
		dgsEditorPropertiesMenuDetach(true)
		dgsEditorPropertiesMenuAttach(element)
		return true
	end,
	returnProperty = function(action)
		local element,property,newValue,oldValue = unpack(action.arguments)
		element[property] = newValue
		local tempPropertyList = element.dgsEditorPropertyList
		if not tempPropertyList then tempPropertyList = {} end
		tempPropertyList[property] = newValue
		element.dgsEditorPropertyList = tempPropertyList
		dgsEditorPropertiesMenuDetach(true)
		dgsEditorPropertiesMenuAttach(element)
		return true
	end,
}
setmetatable(dgsEditor.Action,{__index = function(self, theIndex)
    return setmetatable({action=theIndex},{ __call = function(self,...)
        self.arguments = {...}
        self.result = {dgsEditor.ActionFunctions[self.action](self)}
        return self
    end})
end})
------------------------------------------------------State Switch
function dgsEditorSwitchState(state)
	--If someone want to enable dgs editor
	if state == "enabled" then
		if dgsEditorContext.state == "available" then --First, state need to be "available"
			dgsEditor.state = "enabled"	--Enabled
			dgsEditorMakeOutput(translateText({"EditorEnabled"}))
			triggerEvent("onClientDGSEditorStateChanged",resourceRoot,dgsEditor.state)
			if not dgsEditor.Created then
				loadstring(exports[dgsEditorContext.dgsResourceName]:dgsImportOOPClass())()
				dgsRootInstance:setElementKeeperEnabled(true)
				--Set translation dictionary whenever a new language applies
				dgsRootInstance:setTranslationTable("DGSEditorLanguage",Language.UsingLanguageTable)
				--Use this dictionary
				dgsRootInstance:setAttachTranslation("DGSEditorLanguage")
				dgsEditorCreateMainPanel()
			else
				dgsEditor.BackGround.visible = true
			end
			showCursor(true)
		end
	elseif state == "disabled" then		--If someone want to disable dgs editor
		--Just disable
		dgsEditor.state = "disabled"
		dgsEditorMakeOutput(translateText({"EditorDisabled"}))
		dgsEditor.BackGround.visible = false
		showCursor(false)
		triggerEvent("onClientDGSEditorStateChanged",resourceRoot,dgsEditor.state)
	end
end
addEventHandler("onClientDGSEditorRequestStateChange",root,dgsEditorSwitchState)

--Alt + D
bindKey("d","down",function()
	if getKeyState("lalt") then
		triggerEvent("onClientDGSEditorRequestStateChange",resourceRoot,dgsEditor.state == "enabled" and "disabled" or "enabled")
	end
end)

------------------------------------------------------Main Panel
function dgsEditorCreateMainPanel()
	--Used to store created elements createed by user
	dgsEditor.ElementList = {}
	dgsEditor.Created = true
	--Main Background
	dgsEditor.BackGround = dgsImage(0,0,1,1,_,true,tocolor(0,0,0,100))
	--Main Canvas
	dgsEditor.Canvas = dgsEditor.BackGround:dgsScalePane(0.2,0.2,0.6,0.6,true,sW,sH)
		:on("dgsDrop",function(data)
			local cursorX,cursorY = dgsRootInstance:getCursorPosition(source)
			dgsEditorCreateElement(data,cursorX,cursorY)
		end)
	dgsEditor.Canvas.bgColor = tocolor(0,0,0,128)
	--Widgets Window
	dgsEditor.WidgetMain = dgsEditor.BackGround:dgsWindow(0,0,250,0.5*sH,{"DGSWidgets"},false)
		:setCloseButtonEnabled(false)
		:setSizable(false)
		:setMovable(false)
		:setProperties({
			shadow = {1,1,0xFF000000},
			titleColorBlur = false,
			color = tocolor(0,0,0,128),
			titleColor = tocolor(0,0,0,128),
			textSize = {1.3,1.3},
		})
	--The Vertical Spliter Line
	dgsEditor.WidgetSpliter = dgsEditor.WidgetMain
		:dgsImage(80,0,5,0.5*sH-25,_,false,tocolor(50,50,50,200))
	--Type List
	dgsEditor.WidgetTypeList = dgsEditor.WidgetMain
		:dgsGridList(0,0,80,200,false)
		:setProperties({
			rowHeight = 30,
			columnHeight = 0,
			rowTextSize = {1.2,1.2},
			scrollBarThick = 10,
			bgColor = tocolor(0,0,0,0),
			sortEnabled = false,
		})
		:on("dgsGridListSelect",function(rNew,_,rOld,_)
			if rOld ~= -1 then
				

				if rNew == -1 then
					source:setSelectedItem(rOld)
				end
			end
		end)
	dgsEditor.WidgetTypeList:addColumn("",0.9)
	dgsEditor.WidgetTypeList:addRow(_,{"Basic"})
	dgsEditor.WidgetTypeList:addRow(_,{"Plugins"})
	--Widget List
	dgsEditor.WidgetList = dgsEditor.WidgetMain
		:dgsGridList(85,0,165,0.5*sH-25,false)
		:setProperties({
			rowHeight = 30,
			columnHeight = 0,
			rowTextSize = {1.2,1.2},
			scrollBarThick = 10,
			bgColor = tocolor(0,0,0,0),
			sortEnabled = false,
		})
		:on("dgsGridListSelect",function(rNew,_,rOld,_)
			if rOld ~= -1 then


				if rNew == -1 then
					source:setSelectedItem(rOld)
				end
			end
		end)
		:on("dgsGridListItemDoubleClick",function(button,state,row)
			if button == "left" and state == "down" then
				if row and row ~= -1 then
					local widgetID = source:getItemData(row,1)
					dgsEditorCreateElement(DGSTypeReference[widgetID][1])
				end
			end
		end)
		:on("dgsDrag",function()
			local selectedItem = source:getSelectedItem()
			if selectedItem ~= -1 then
				local widgetID = source:getItemData(selectedItem,1)
				local widgetIcon = source:getItemImage(selectedItem,1)
				source:sendDragNDropData(DGSTypeReference[widgetID][1],widgetIcon)
			end
		end)
	
	dgsEditor.WidgetList:addColumn(_,0.2)	--Icon
	dgsEditor.WidgetList:addColumn(_,0.7)	--Namne
	for i=1,#DGSTypeReference do
		local row = dgsEditor.WidgetList:addRow(_,_,{DGSTypeReference[i][2]})
		local texture = DxTexture("icons/"..DGSTypeReference[i][2]..".png")
		dgsRootInstance:attachToAutoDestroy(texture,dgsEditor.WidgetList)
		dgsEditor.WidgetList:setItemImage(row,1,texture)
		dgsEditor.WidgetList:setItemData(row,1,i)
	end
	--[[
	dgsEditor.PluginList = dgsEditor.WidgetMain	--PluginList List
		:dgsGridList(85,0,155,370,false)
		:setProperty("rowHeight",30)
		:setProperty("columnHeight",0)
		:setProperty("rowTextSize",{1.2,1.2})
		:setProperty("bgColor",tocolor(0,0,0,0))
		:on("dgsGridListSelect",function(rNew,_,rOld,_)
			if rOld ~= -1 then
				
				if rNew == -1 then
					source:setSelectedItem(rOld)
				end
			end
		end)
		:on("dgsGridListItemDoubleClick",function(row)
			
		end)
	dgsEditor.WidgetList:addColumn(_,0.2)
	dgsEditor.WidgetList:addColumn(_,0.7)
	for i=1,#DGSTypeReference do
		dgsEditor.WidgetList:addRow(_,_,{DGSTypeReference[i][2]})
	end
	
	dgsEditor.PropertyList = dgsWindow(0,0,200,400,{"DGSPropertyList"})
		:center()
		:setCloseButtonEnabled(false)
		:setSizable(false)
		:setProperty("color",tocolor(0,0,0,128))
		:setProperty("titleColor",tocolor(0,0,0,128))
		:setLayer("top")]]

	--Properties Main
	dgsEditor.WidgetPropertiesMain  = dgsEditor.BackGround:dgsWindow(sW-350,0,350,0.5*sH,{"DGSProperties"},false)
		:setCloseButtonEnabled(false)
		--:setSizable(false)
		:setMovable(false)
		:setProperties({
			shadow = {1,1,0xFF000000},
			titleColorBlur = false,
			color = tocolor(0,0,0,128),
			titleColor = tocolor(0,0,0,128),
			textSize = {1.3,1.3},
			minSize = {350,0.5*sH},
			maxSize = {350,sH},
			borderSize = 10,
		})
	--Properties List
	dgsEditor.WidgetPropertiesMenu = dgsEditor.WidgetPropertiesMain
		:dgsGridList(0,0,350,0.5*sH-dgsEditor.WidgetPropertiesMain.titleHeight-dgsEditor.WidgetPropertiesMain.borderSize,false)
		:setProperties({
			columnHeight = 0,
			rowHeight = 30,
			sortEnabled = false,
			scrollBarState = {nil,false},
			rowTextPosOffset = {10,0},
		})
	
	--Resize grid list
	dgsEditor.WidgetPropertiesMain:on("dgsSizeChange",function()
		local w,h = source:getSize()
		dgsEditor.WidgetPropertiesMenu:setSize(w,h-source.titleHeight-source.borderSize)
	end)

	--set rows default color
	local defaultRowColor = dgsEditor.WidgetPropertiesMenu.rowColor[1]
	dgsEditor.WidgetPropertiesMenu:setProperty("rowColor",{defaultRowColor,defaultRowColor,defaultRowColor})

	dgsEditor.WidgetPropertiesMenu:addColumn("",0.45)	--property name
	dgsEditor.WidgetPropertiesMenu:addColumn("",0.55)	--edit
	
	dgsEditor.Controller = dgsEditorCreateController(dgsEditor.Canvas)
	dgsEditorCreateColorPicker()
	dgsEditorCreateGenerateCode()
end
-----------------------------------------------------Element management
function dgsEditorCreateElement(...)
	local args = {...}
--	if #arguments == 0 then
	local createdElement
	local dgsType,x,y = unpack(args)
	if dgsType == "dgs-dxbutton" then
		createdElement = dgsEditor.Canvas:dgsButton(0,0,80,30,"Button",false)
	elseif dgsType == "dgs-dximage" then
		createdElement = dgsEditor.Canvas:dgsImage(0,0,80,80,_,false)
	elseif dgsType == "dgs-dxcheckbox" then
		createdElement = dgsEditor.Canvas:dgsCheckBox(0,0,80,30,"Check Box",false,false)
	elseif dgsType == "dgs-dxradiobutton" then
		createdElement = dgsEditor.Canvas:dgsRadioButton(0,0,80,30,"Radio Button",false)
	elseif dgsType == "dgs-dxedit" then
		createdElement = dgsEditor.Canvas:dgsEdit(0,0,100,30,"Edit",false)
	elseif dgsType == "dgs-dxgridlist" then
		createdElement = dgsEditor.Canvas:dgsGridList(0,0,100,100,false)
	elseif dgsType == "dgs-dxscrollpane" then
		createdElement = dgsEditor.Canvas:dgsScrollPane(0,0,100,100,false)
	elseif dgsType == "dgs-dxcombobox" then
		createdElement = dgsEditor.Canvas:dgsComboBox(0,0,100,30,false)
	elseif dgsType == "dgs-dxmemo" then
		createdElement = dgsEditor.Canvas:dgsMemo(0,0,100,60,"Memo",false)
	elseif dgsType == "dgs-dxprogressbar" then
		createdElement = dgsEditor.Canvas:dgsProgressBar(0,0,100,30,false)
	elseif dgsType == "dgs-dxlabel" then
		createdElement = dgsEditor.Canvas:dgsLabel(0,0,50,30,"Label",false)
	elseif dgsType == "dgs-dxscrollbar" then
		createdElement = dgsEditor.Canvas:dgsScrollBar(0,0,20,150,false,false)
	elseif dgsType == "dgs-dxswitchbutton" then
		createdElement = dgsEditor.Canvas:dgsSwitchButton(0,0,80,20,"On","Off",false)
	elseif dgsType == "dgs-dxselector" then
		createdElement = dgsEditor.Canvas:dgsSelector(0,0,80,20,false)
	elseif dgsType == "dgs-dxwindow" then
		createdElement = dgsEditor.Canvas:dgsWindow(0,0,100,100,"window",false)
			:setMovable(false)
			:setSizable(false)
	elseif dgsType == "dgs-dxtabpanel" then
		createdElement = dgsEditor.Canvas:dgsTabPanel(0,0,100,100,false)
	end
	if x and y then createdElement:setPosition(x,y,false,true) end
	createdElement.isCreatedByEditor = true
	--When clicking the element
	createdElement:on("dgsMouseClickDown",function(button,state)
		if button == "left" then
			if dgsEditor.Controller.FindParent then
				--Set the parent to the element
				local c = dgsGetInstance(dgsEditor.Controller.BoundChild)
				if c == createdElement then return end
				c:setParent(createdElement)
				c.position.relative = dgsEditor.Controller.position.relative
				c.position = {0,0}
				c.size.relative = dgsEditor.Controller.size.relative
				c.size = dgsEditor.Controller.size
				dgsEditor.Controller.FindParent = nil
				dgsEditorPropertiesMenuDetach(true)
				dgsEditorControllerAttach(c)
			else
				--Don't attach if the element is already attached
				if dgsEditor.Controller.BoundChild and dgsEditor.Controller.BoundChild == createdElement.dgsElement then
					--Make the target element move back
					createdElement:moveToBack()
					return
				end
				--Just click
				dgsEditorControllerDetach()
				--When clicked the element, turn it into "operating element"
				dgsEditor.Controller.visible = true	--Make the controller visible
				dgsEditorControllerAttach(createdElement)
			end
		end
	end)
	--Record the element
	dgsEditor.ElementList[createdElement.dgsElement] = createdElement
	--Add action
	saveAction("destroy",{createdElement})
	return createdElement
end

function dgsEditorControllerAttach(targetElement)
	--Save position/size
	local pos,size = targetElement.position,targetElement.size
	--Record the parent element of operating element
	dgsEditor.Controller.BoundParent = targetElement:getParent().dgsElement
	--Record the operating element as the child element of controller (to proxy the positioning and resizing of operating element with controller)
	dgsEditor.Controller.BoundChild = targetElement.dgsElement
	--Set the parent element
	dgsEditor.Controller:setParent(targetElement:getParent())
	--Set the child element
	targetElement:setParent(dgsEditor.Controller)
	--Use operating element's position
	dgsEditor.Controller.position = pos
	--Use operating element's size
	dgsEditor.Controller.size = size
	--Make operating element fullscreen to the controller
	targetElement.position.relative = true
	targetElement.position.x = 0
	targetElement.position.y = 0
	targetElement.size.relative = true
	targetElement.size.w = 1
	targetElement.size.h = 1
	--Make the 8 circle controller always front
	for i=1,#dgsEditor.Controller.controller do
		dgsGetInstance(dgsEditor.Controller.controller[i]):bringToFront()
	end
	dgsEditorPropertiesMenuAttach(targetElement)
end

function dgsEditorControllerDetach()
	--Remove find parent
	dgsEditor.Controller.FindParent = nil
	--Get the instance of parent (controller's & operating element's)
	local p = dgsGetInstance(dgsEditor.Controller.BoundParent)
	--If the operating element exists
	if dgsEditor.Controller.BoundChild then
		--Get the instance of child (controller's) [the operating element]
		local c = dgsGetInstance(dgsEditor.Controller.BoundChild)
		dgsEditor.Controller.BoundChild = nil
		--Use the position/size/parent of the controller
		c:setParent(p)
		c.position.relative = dgsEditor.Controller.position.relative
		c.position = dgsEditor.Controller.position
		c.size.relative = dgsEditor.Controller.size.relative
		c.size = dgsEditor.Controller.size
	end
	dgsEditorPropertiesMenuDetach()
end

local ctrlSize = 10
--Controller Create Function  
function dgsEditorCreateController(theCanvas)
	--Declear the 8 controlling circles
	local RightCenter,RightTop,CenterTop,LeftTop,LeftCenter,LeftBottom,CenterBottom,RightBottom	
	local Ring = dgsCreateCircle(0.45,0.3,360)	--circles
	dgsCircleSetColorOverwritten(Ring,false)
	local Line = theCanvas:dgsLine(0,0,0,0,false,2,tocolor(255,0,0,255))	--the highlight line (controller)
		:setProperties({
			childOutsideHit = true,
			isController = true,
		})
	--When clicking the element
	addEventHandler("onDgsMouseClickDown",root,function(button,state,mx,my)
		--Check whether the clicked element is handled by the controller
		if dgsGetInstance(source) == dgsGetInstance(dgsEditor.Controller.BoundChild) then
			--Save the position, size and mouse position
			dgsEditor.Controller.startDGSPos = Vector2(dgsEditor.Controller:getPosition(false))
			dgsEditor.Controller.startDGSSize = Vector2(dgsEditor.Controller:getSize(false))
			dgsEditor.Controller.startMousePos = Vector2(mx,my)
		end
	end)
	--When attempt to moving the element
	addEventHandler("onDgsMouseDrag",root,function(mx,my)
		--Check whether the clicked element is handled by the controller
		if dgsGetInstance(source) == dgsGetInstance(dgsEditor.Controller.BoundChild) then
			--Is the element is able to move?
			if dgsEditor.Controller.startMousePos then
				--Move
				local pRlt = dgsEditor.Controller.position.rlt
				local mPos = Vector2(mx,my)
				dgsEditor.Controller.position = Vector2(mx,my)-(dgsEditor.Controller.startMousePos-dgsEditor.Controller.startDGSPos)
			end
		end
	end)
	--Draw 4 lines
	Line:addItem(0,0,1,0,_,_,true)
	Line:addItem(1,0,1,1,_,_,true)
	Line:addItem(1,1,0,1,_,_,true)
	Line:addItem(0,1,0,0,_,_,true)
	--8 circles controller creating and resizing function
	local RightCenter = Line:dgsButton(-ctrlSize/2,0,ctrlSize,ctrlSize,"",false)
		:setProperties({
			image = {Ring,Ring,Ring},
			color = {predefColors.hlightN,predefColors.hlightH,predefColors.hlightC},
		})
		:setPositionAlignment("right","center")
		:on("dgsMouseClickDown",function(button,state,mx,my)
			source.parent.startDGSPos = Vector2(source.parent:getPosition(false))
			source.parent.startDGSSize = Vector2(source.parent:getSize(false))
			source.parent.startMousePos = Vector2(mx,my)
		end)
		:on("dgsMouseDrag",function(mx,my)
			if source.parent.startMousePos then
				local pRlt = source.parent.position.rlt
				local sRlt = source.parent.size.rlt
				local mPos = Vector2(mx,my)
				source.parent.size = Vector2(-source.parent.startMousePos.x+mPos.x+source.parent.startDGSSize.x,source.parent.startDGSSize.y)
			end
		end)
	local CenterTop = Line:dgsButton(0,-ctrlSize/2,ctrlSize,ctrlSize,"",false)
		:setProperties({
			image = {Ring,Ring,Ring},
			color = {predefColors.hlightN,predefColors.hlightH,predefColors.hlightC},
		})
		:setPositionAlignment("center","top")
		:on("dgsMouseClickDown",function(button,state,mx,my)
			source.parent.startDGSPos = Vector2(source.parent:getPosition(false))
			source.parent.startDGSSize = Vector2(source.parent:getSize(false))
			source.parent.startMousePos = Vector2(mx,my)
		end)
		:on("dgsMouseDrag",function(mx,my)
			if source.parent.startMousePos then
				local pRlt = source.parent.position.rlt
				local sRlt = source.parent.size.rlt
				local mPos = Vector2(mx,my)
				source.parent.position = Vector2(source.parent.startDGSPos.x,mPos.y-(source.parent.startMousePos.y-source.parent.startDGSPos.y))
				source.parent.size = Vector2(source.parent.startDGSSize.x,source.parent.startMousePos.y-mPos.y+source.parent.startDGSSize.y)
			end
		end)
	local LeftTop = Line:dgsButton(-ctrlSize/2,-ctrlSize/2,ctrlSize,ctrlSize,"",false)
		:setProperties({
			image = {Ring,Ring,Ring},
			color = {predefColors.hlightN,predefColors.hlightH,predefColors.hlightC},
		})
		:setPositionAlignment("left","top")
		:on("dgsMouseClickDown",function(button,state,mx,my)
			source.parent.startDGSPos = Vector2(source.parent:getPosition(false))
			source.parent.startDGSSize = Vector2(source.parent:getSize(false))
			source.parent.startMousePos = Vector2(mx,my)
		end)
		:on("dgsMouseDrag",function(mx,my)
			if source.parent.startMousePos then
				local pRlt = source.parent.position.rlt
				local sRlt = source.parent.size.rlt
				local mPos = Vector2(mx,my)
				source.parent.position = mPos-(source.parent.startMousePos-source.parent.startDGSPos)
				source.parent.size = (source.parent.startMousePos-mPos+source.parent.startDGSSize)
			end
		end)
	local LeftCenter = Line:dgsButton(-ctrlSize/2,0,ctrlSize,ctrlSize,"",false)
		:setProperties({
			image = {Ring,Ring,Ring},
			color = {predefColors.hlightN,predefColors.hlightH,predefColors.hlightC},
		})
		:setPositionAlignment("left","center")
		:on("dgsMouseClickDown",function(button,state,mx,my)
			source.parent.startDGSPos = Vector2(source.parent:getPosition(false))
			source.parent.startDGSSize = Vector2(source.parent:getSize(false))
			source.parent.startMousePos = Vector2(mx,my)
		end)
		:on("dgsMouseDrag",function(mx,my)
			if source.parent.startMousePos then
				local pRlt = source.parent.position.rlt
				local sRlt = source.parent.size.rlt
				local mPos = Vector2(mx,my)
				source.parent.position = Vector2(mPos.x-(source.parent.startMousePos.x-source.parent.startDGSPos.x),source.parent.startDGSPos.y)
				source.parent.size = Vector2(source.parent.startMousePos.x-mPos.x+source.parent.startDGSSize.x,source.parent.startDGSSize.y)
			end
		end)
	local LeftBottom = Line:dgsButton(-ctrlSize/2,-ctrlSize/2,ctrlSize,ctrlSize,"",false)
		:setProperties({
			image = {Ring,Ring,Ring},
			color = {predefColors.hlightN,predefColors.hlightH,predefColors.hlightC},
		})
		:setPositionAlignment("left","bottom")
		:on("dgsMouseClickDown",function(button,state,mx,my)
			source.parent.startDGSPos = Vector2(source.parent:getPosition(false))
			source.parent.startDGSSize = Vector2(source.parent:getSize(false))
			source.parent.startMousePos = Vector2(mx,my)
		end)
		:on("dgsMouseDrag",function(mx,my)
			if source.parent.startMousePos then
				local pRlt = source.parent.position.rlt
				local sRlt = source.parent.size.rlt
				local mPos = Vector2(mx,my)
				source.parent.position = Vector2(mPos.x-(source.parent.startMousePos.x-source.parent.startDGSPos.x),source.parent.startDGSPos.y)
				source.parent.size = ((source.parent.startMousePos-mPos)*Vector2(1,-1)+source.parent.startDGSSize)
			end
		end)
	local CenterBottom = Line:dgsButton(0,-ctrlSize/2,ctrlSize,ctrlSize,"",false)
		:setProperties({
			image = {Ring,Ring,Ring},
			color = {predefColors.hlightN,predefColors.hlightH,predefColors.hlightC},
		})
		:setPositionAlignment("center","bottom")
		:on("dgsMouseClickDown",function(button,state,mx,my)
			source.parent.startDGSPos = Vector2(source.parent:getPosition(false))
			source.parent.startDGSSize = Vector2(source.parent:getSize(false))
			source.parent.startMousePos = Vector2(mx,my)
		end)
		:on("dgsMouseDrag",function(mx,my)
			if source.parent.startMousePos then
				local pRlt = source.parent.position.rlt
				local mPos = Vector2(mx,my)
				source.parent.size = Vector2(source.parent.startDGSSize.x,-source.parent.startMousePos.y+mPos.y+source.parent.startDGSSize.y)
			end
		end)
	local RightBottom = Line:dgsButton(-ctrlSize/2,-ctrlSize/2,ctrlSize,ctrlSize,"",false)
		:setProperties({
			image = {Ring,Ring,Ring},
			color = {predefColors.hlightN,predefColors.hlightH,predefColors.hlightC},
		})
		:setPositionAlignment("right","bottom")
		:on("dgsMouseClickDown",function(button,state,mx,my)
			source.parent.startDGSPos = Vector2(source.parent:getPosition(false))
			source.parent.startDGSSize = Vector2(source.parent:getSize(false))
			source.parent.startMousePos = Vector2(mx,my)
		end)
		:on("dgsMouseDrag",function(mx,my)
			if source.parent.startMousePos then
				local pRlt = source.parent.position.rlt
				local sRlt = source.parent.size.rlt
				local mPos = Vector2(mx,my)
				source.parent.size = ((source.parent.startMousePos-mPos)*Vector2(-1,-1)+source.parent.startDGSSize)
			end
		end)
	local RightTop = Line:dgsButton(-ctrlSize/2,-ctrlSize/2,ctrlSize,ctrlSize,"",false)
		:setProperties({
			image = {Ring,Ring,Ring},
			color = {predefColors.hlightN,predefColors.hlightH,predefColors.hlightC},
		})
		:setPositionAlignment("right","top")
		:on("dgsMouseClickDown",function(button,state,mx,my)
			source.parent.startDGSPos = Vector2(source.parent:getPosition(false))
			source.parent.startDGSSize = Vector2(source.parent:getSize(false))
			source.parent.startMousePos = Vector2(mx,my)
		end)
		:on("dgsMouseDrag",function(mx,my)
			if source.parent.startMousePos then
				local pRlt = source.parent.position.rlt
				local sRlt = source.parent.size.rlt
				local mPos = Vector2(mx,my)
				source.parent.position = Vector2(source.parent.startDGSPos.x,mPos.y-(source.parent.startMousePos.y-source.parent.startDGSPos.y))
				source.parent.size = ((source.parent.startMousePos-mPos)*Vector2(-1,1)+source.parent.startDGSSize)
			end
		end)
	--Record the 8 circle controller
	Line.controller = {
		RightCenter.dgsElement,
		CenterTop.dgsElement,
		LeftTop.dgsElement,
		LeftCenter.dgsElement,
		LeftBottom.dgsElement,
		CenterBottom.dgsElement,
		RightBottom.dgsElement,
		RightTop.dgsElement,
	}
	Line.visible = false
	--When clicking the canvas, hide the controller
	theCanvas:on("dgsMouseClickDown",function(button,state)
		if button == "left" then
			Line.visible = false
			dgsEditorControllerDetach()
		end
	end)
	return Line
end

dgsEditorAttachProperty = {
	Number = function(targetElement,property,row,offset,text,i,t)
		if property == "absPos" or property == "absSize" or property == "rltPos" or property == "rltSize" then
			targetElement = dgsEditor.Controller
		end
		local arg = targetElement[property]
		if t and type(arg) == "table" then arg = arg[t] end
		if i and type(arg) == "table" then arg = arg[i] end
		--iprint("NUMBER",property,arg)
		if not arg then arg = 0 end
		dgsEditor.WidgetPropertiesMenu:dgsEdit(offset or 0,5,50,20,arg,false)
			:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
			:on("dgsTextChange",function()
				changeProperty(targetElement,property,tonumber(source:getText()),i,t)
			end)
	end,
	Bool = function(targetElement,property,row,offset,text,i,t)
		local arg = property == "noCloseButton" and targetElement:getCloseButtonEnabled() or targetElement[property]
		if t and type(arg) == "table" then arg = arg[t] end
		if i and type(arg) == "table" then arg = arg[i] end
		--iprint("BOOL",property,arg)
		dgsEditor.WidgetPropertiesMenu:dgsSwitchButton(offset or 0,5,50,20,"","",arg)
			:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
			:on("dgsSwitchButtonStateChange",function(state)
				changeProperty(targetElement,property,state,i,t)
			end)
	end,
	String = function(targetElement,property,row,offset,text,i,t)
		local arg = targetElement[property]
		if t and type(arg) == "table" then arg = arg[t] end
		if i and type(arg) == "table" then arg = arg[i] end
		--iprint("STRING",property,arg)
		if not arg then arg = "" end
		if property:lower():find("align") or (text and text:lower():find("align")) then
			--Align combobox
			local combobox = dgsEditor.WidgetPropertiesMenu:dgsComboBox(offset or 0,5,150,20,false)
				:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
			for i, align in pairs(alignments[text or "alignX"]) do
				combobox:addItem(align)
				if align == arg then
					combobox:setSelectedItem(i)
				end
			end
			combobox:on("dgsComboBoxSelect",function(row)
				changeProperty(targetElement,property,source:getItemText(row),i,t)
			end)
		elseif property:lower():find("font") then
			--Font combobox
			local combobox = dgsEditor.WidgetPropertiesMenu:dgsComboBox(offset or 0,5,150,20,false)
				:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
			for i, font in pairs(fonts) do
				combobox:addItem(font)
				if font == arg then
					combobox:setSelectedItem(i)
				end
			end
			combobox:on("dgsComboBoxSelect",function(row)
				changeProperty(targetElement,property,source:getItemText(row),i,t,"quotes")
			end)
		else
			dgsEditor.WidgetPropertiesMenu:dgsEdit(offset or 0,5,150,20,arg,false)
				:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
				:on("dgsTextChange",function()
					changeProperty(targetElement,property,source:getItemText(row),i,t)
				end)
		end
	end,
	Color = function(targetElement,property,row,offset,text,i,t)
		local arg = targetElement[property]
		if t and type(arg) == "table" then arg = arg[t] end
		local text = property
		if i then
			if type(arg) == "table" then
				arg = arg[i]
			end
			if DGSPropertyItemNames[property] then
				text = DGSPropertyItemNames[property][i] or property
			end
		end
		--iprint("COLOR",property,arg)
		if not arg or type(arg) == "table" then arg = tocolor(0,0,0,0) end
		local r,g,b,a = fromcolor(arg,true)
		local shader = dxCreateShader("client/alphaCircle.fx")
		local imgBack = dgsEditor.WidgetPropertiesMenu
			:dgsImage(offset or 0,5,20,20,shader,false)
			:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
		dgsAttachToAutoDestroy(shader,imgBack.dgsElement)
		local circleImage = dgsCreateCircle(0.48,0,360,tocolor(r,g,b,a))
		dxSetShaderValue(circleImage,"borderSoft",0.02)
		dgsAddPropertyListener(circleImage,"color")
		addEventHandler("onDgsPropertyChange",circleImage,function(key,newValue,oldValue)
			if key == "color" then
				changeProperty(targetElement,property,tocolor(fromcolor(newValue,true)),i,t,"color")
			end
		end)
		local img = dgsEditor.WidgetPropertiesMenu
			:dgsImage(offset or 0,5,20,20,circleImage,false)
			:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
			:on("dgsMouseClickUp",function()
				dgsEditor.WidgetColorMain.visible = true
				local x,y = source:getPosition(false,true)
				local w,h = unpack(source.size)
				dgsEditor.WidgetColorMain.position.x = sW-dgsEditor.WidgetColorMain.size.w
				dgsEditor.WidgetColorMain.position.y = y+h+5
				dgsEditor.WidgetColorMain:bringToFront()
				dgsEditor.WidgetColorMain:setText(targetElement:getType()..", "..text)
				dgsEditor.ColorPicker.childImage = source:getImage()
				local r,g,b,a = fromcolor(dgsCircleGetColor(dgsEditor.ColorPicker.childImage),true)
				dgsEditor.ColorPicker:setColor(r,g,b,a,"RGB")
				dgsSetProperty(dgsEditor.ColorPicker.oldImage.dgsElement,"color",tocolor(r,g,b,a))
			end)
		img:applyDetectArea(dgsEditor.DA)
	end,
	Text = function(targetElement,property,row,offset,text,i,t)
		local arg = targetElement[property]
		if t and type(arg) == "table" then arg = arg[t] end
		if i and type(arg) == "table" then arg = arg[i] end
		--iprint("TEXT",property,arg)
		if not arg then arg = "" end
		dgsEditor.WidgetPropertiesMenu:dgsEdit(offset or 0,5,150,20,arg,false)
			:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
			:on("dgsTextChange",function()
				changeProperty(targetElement,property,source:getText(),i,t,"color")
			end)
	end,
	add = function(targetElement,property,row,offset,text,i,t)
		dgsEditor.WidgetPropertiesMenu:dgsButton(10,5,150,20,"add "..property,false)
			:setProperty("alignment",{"center","center"})
			:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
			:on("dgsMouseClickUp",function()
				local values = {}
				local propertyValues = dgsGetRegisteredProperties(targetElement:getType(),true)[property]
				for a, arguments in pairs(propertyValues) do
					if type(arguments) == "table" then
						if arguments[1] == 1 then break end
						values[a] = {}
						for b, args in pairs(arguments) do
							if type(args) == "table" then
								values[b] = {}
								for c, arg in pairs(args) do
									local arg = dgsListPropertyTypes(arg)
									if type(arg) == "table" then arg = arg[2] or arg[1] end
									local value
									if arg == "Number" then value = 0 end
									if arg == "Bool" then value = false end
									if arg == "String" then value = "" end
									if arg == "Color" then value = tocolor(0,0,0,255) end
									if arg == "Text" then value = "" end
									values[b][c] = value
								end
							else
								local arg = dgsListPropertyTypes(args)
								if type(arg) == "table" then arg = arg[2] or arg[1] end
								local value
								if arg == "Number" then value = 0 end
								if arg == "Bool" then value = false end
								if arg == "String" then value = "" end
								if arg == "Color" then value = tocolor(0,0,0,255) end
								if arg == "Text" then value = "" end
								values[b] = value
							end
						end
					end
				end
				changeProperty(targetElement,property,values)
				values = nil
				dgsEditorPropertiesMenuDetach(true)
				dgsEditorPropertiesMenuAttach(targetElement)
			end)
	end,
}

function dgsEditorPropertiesMenuAttach(targetElement)
	--Window type element
	dgsEditor.WidgetPropertiesMain:setText("DGSProperties, "..targetElement:getType())
	local propertiesList = dgsGetRegisteredProperties(targetElement:getType(),true)
	local keys = table.listKeys(propertiesList)
	table.sort(keys)
	for i=1,#keys do
		local property = keys[i]
		local pTemplate = propertiesList[property]
		for t, arguments in pairs(pTemplate) do
			if type(arguments) == "table" then
				--Сhecking whether this property is set
				if targetElement[property] and type(targetElement[property]) == "table" and #targetElement[property] > 0 then
					if #pTemplate > 1 and pTemplate[#pTemplate] ~= 1 then
						--If there are several arguments in the argument
						for i, arg in pairs(arguments) do
							if type(arg) == "table" then
								for c, a in pairs(arg) do
									local arg = dgsListPropertyTypes(a)
									local arg = arg[2] or arg[1]
									local attach = dgsEditorAttachProperty[arg]
									if attach then
										--Add row section
										local text = DGSPropertyItemNames[property] and DGSPropertyItemNames[property][i] or i
										if c == 1 then
											local rowSection = dgsEditor.WidgetPropertiesMenu:addRow(rowSection,property.." "..(text[c] or ""))
											dgsEditor.WidgetPropertiesMenu:setRowAsSection(rowSection,true)
										end
										local row = dgsEditor.WidgetPropertiesMenu:addRow(row,text[c+1])
										attach(targetElement,property,row,0,text[i+c],c,i)
									end
								end
							else
								local arg = dgsListPropertyTypes(arg)
								local arg = arg[2] or arg[1]
								local attach = dgsEditorAttachProperty[arg]
								if attach then
									--Add row section
									local text = DGSPropertyItemNames[property] and DGSPropertyItemNames[property][t] or t
									if i == 1 then
										local rowSection = dgsEditor.WidgetPropertiesMenu:addRow(rowSection,property.." "..(text[i] or ""))
										dgsEditor.WidgetPropertiesMenu:setRowAsSection(rowSection,true)
									end
									local row = dgsEditor.WidgetPropertiesMenu:addRow(row,text[i+1])
									attach(targetElement,property,row,0,text[i+1],i,t)
								end
							end
						end
					else
						--If there are several arguments
						for i, arg in pairs(arguments) do
							local arg = dgsListPropertyTypes(arg)
							local arg = arg[2] or arg[1]
							local attach = dgsEditorAttachProperty[arg]
							if attach then
								--Add row section
								if i == 1 then
									local rowSection = dgsEditor.WidgetPropertiesMenu:addRow(rowSection,property)
									dgsEditor.WidgetPropertiesMenu:setRowAsSection(rowSection,true)
								end
								local text = DGSPropertyItemNames[property] and DGSPropertyItemNames[property][i] or i
								local row = dgsEditor.WidgetPropertiesMenu:addRow(row,text)
								attach(targetElement,property,row,0,text,i)
							end
						end
					end
				else
					--Add a button to add a property
					local row = dgsEditor.WidgetPropertiesMenu:addRow(row,property)
					dgsEditor.WidgetPropertiesMenu:setRowAsSection(row,true)
					dgsEditorAttachProperty.add(targetElement,property,row)
					break
				end
			else
				--If one argument
				local arg = dgsListPropertyTypes(arguments)
				local arg = arg[1] or arg[2]
				local attach = dgsEditorAttachProperty[arg]
				if attach then
					local row = dgsEditor.WidgetPropertiesMenu:addRow(row,property)
					dgsEditor.WidgetPropertiesMenu:setRowAsSection(row,true)
					attach(targetElement,property,row,10)
				end
			end
		end
	end
	--row parent element
	local p = dgsGetInstance(dgsEditor.Controller.BoundParent)
	if p and p ~= dgsEditor.Canvas then
		local row = dgsEditor.WidgetPropertiesMenu:addRow(_,"parent")
		dgsEditor.WidgetPropertiesMenu:setRowAsSection(row,true)
		local rowSection = dgsEditor.WidgetPropertiesMenu:addRow(_,"")
		dgsEditor.WidgetPropertiesMenu:dgsLabel(10,5,150,20,p:getType(),false)
			:setProperty("alignment",{"center","center"})
			:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
		dgsEditor.WidgetPropertiesMenu:dgsButton(0,5,150,20,"remove parent",false)
			:setProperty("alignment",{"center","center"})
			:attachToGridList(dgsEditor.WidgetPropertiesMenu,rowSection,2)
			:on("dgsMouseClickUp",function()
				local c = dgsGetInstance(dgsEditor.Controller.BoundChild)
				--Set parent element the Canvas
				c:setParent(dgsEditor.Canvas)
				c.position.relative = dgsEditor.Controller.position.relative
				c.position = {0,0}
				c.size.relative = dgsEditor.Controller.size.relative
				c.size = dgsEditor.Controller.size
				dgsEditorPropertiesMenuDetach(true)
				dgsEditorControllerAttach(c)
			end)
	else
		local row = dgsEditor.WidgetPropertiesMenu:addRow(_,"parent")
		dgsEditor.WidgetPropertiesMenu:setRowAsSection(row,true)
		dgsEditor.WidgetPropertiesMenu:dgsButton(10,5,150,20,"set parent",false)
			:setProperty("alignment",{"center","center"})
			:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
			:on("dgsMouseClickUp",function()
				source:setText("click on the element")
				--Create find the parent
				dgsEditor.Controller.FindParent = true
			end)
	end
	--row destroy element
	local row = dgsEditor.WidgetPropertiesMenu:addRow(_,"destroy")
	dgsEditor.WidgetPropertiesMenu:setRowAsSection(row,true)
	dgsEditor.WidgetPropertiesMenu:dgsButton(10,5,150,20,"destroy element",false)
		:setProperty("alignment",{"center","center"})
		:attachToGridList(dgsEditor.WidgetPropertiesMenu,row,2)
		:on("dgsMouseClickUp",function()
			dgsEditorDestroyElement(targetElement,true)
		end)
end

function dgsEditorPropertiesMenuDetach(keepPosition)
	dgsEditor.WidgetPropertiesMain:setText("DGSProperties")
	dgsEditor.WidgetPropertiesMenu:clearRow(_,keepPosition)
	for _, child in pairs(dgsEditor.WidgetPropertiesMenu.children) do
		--don't touch scrollbar
		if not child.attachedToParent then
			child:destroy()
		end
	end
end

function dgsEditorCreateColorPicker()
	--Color Main
	dgsEditor.WidgetColorMain = dgsEditor.BackGround:dgsWindow(0,0,390,350,"",false)
		:setCloseButtonEnabled(false)
		:setSizable(false)
		--:setMovable(false)
		:setProperties({
			shadow = {1,1,0xFF000000},
			titleColorBlur = false,
			color = tocolor(69,69,69,255),
			titleColor = tocolor(69,69,69,255),
			textSize = {1.2,1.2},
		})
	
	dgsEditor.WidgetColorMain:dgsImage(0,0,390,1,_,false,tocolor(0,0,0,255))

	--Color Picker
	dgsEditor.ColorPicker = dgsEditor.WidgetColorMain:dgsColorPicker("HSVRing",10,10,160,160,false)

	--RGB selectors
	local RGB = {"R","G","B","A"}
	for i, attr in pairs(RGB) do
		dgsEditor.WidgetColorMain:dgsLabel(200,10+i*30-30,0,15,attr..":",false)
			:setProperty("alignment",{"right","center"})
		if attr == "A" then
			dgsEditor.WidgetColorMain:dgsComponentSelector(205,10+i*30-30,115,15,true,false,_,2)
			:bindToColorPicker(dgsEditor.ColorPicker,"RGB","A")
			local edit = dgsEditor.WidgetColorMain:dgsEdit(325,97.5,50,20,"",false)
				:on("dgsTextChange",function()
					if source:getText() == "" then return end
					if tonumber(source:getText()) > 255 then return source:setText("255") end
				end)
			addElementOutline(edit)
			local btnUp = edit:dgsButton(0.6,0,0.4,0.5," ▲",true)
				:setProperties({
					alignment = {"center","center"},
					textSize = {0.7,0.7},
				})
				:on("dgsMouseClickDown",function()
					local arg = tonumber(source.parent:getText()) or 0
					local arg = arg + 1
					if arg > 255 then arg = 255 end
					source.parent:setText(arg)
				end)
			addElementOutline(btnUp)
			local btnDown = edit:dgsButton(0.6,0.5,0.4,0.5," ▼",true)
				:setProperties({
					alignment = {"center","center"},
					textSize = {0.7,0.7},
				})
				:on("dgsMouseClickDown",function()
					local arg = tonumber(source.parent:getText()) or 0
					local arg = arg - 1
					if arg < 0 then arg = 0 end
					source.parent:setText(arg)
				end)
			addElementOutline(btnDown)
			edit:setWhiteList("[^0-9]")
			edit:bindToColorPicker(dgsEditor.ColorPicker,"RGB","A")
		else
			dgsEditor.WidgetColorMain:dgsComponentSelector(205,10+i*30-30,170,15,true,false,_,2)
				:bindToColorPicker(dgsEditor.ColorPicker,"RGB",attr)
		end
	end

	--HEX edit
	dgsEditor.WidgetColorMain:dgsLabel(200,140,0,20,"HEX:",false)
		:setProperty("alignment",{"right","center"})
	local edit = dgsEditor.WidgetColorMain:dgsEdit(205,140,80,20,"",false)
	addElementOutline(edit)
	edit:bindToColorPicker(dgsEditor.ColorPicker,"#RGBAHEX","RGBA",_,true)
	
		
	--RGB edits
	local RGB = {"R","G","B"}
	for i, attr in pairs(RGB) do
		dgsEditor.WidgetColorMain:dgsLabel(25,190+i*30-30,0,20,attr..":",false)
			:setProperty("alignment",{"right","center"})
		local edit = dgsEditor.WidgetColorMain:dgsEdit(30,190+i*30-30,50,20,"",false)
			:on("dgsTextChange",function()
				if source:getText() == "" then return end
				if tonumber(source:getText()) > 255 then return source:setText("255") end
			end)
		addElementOutline(edit)
		local btnUp = edit:dgsButton(0.6,0,0.4,0.5," ▲",true)
			:setProperties({
				alignment = {"center","center"},
				textSize = {0.7,0.7},
			})
			:on("dgsMouseClickDown",function()
				local arg = tonumber(source.parent:getText()) or 0
				local arg = arg + 1
				if arg > 255 then arg = 255 end
				source.parent:setText(arg)
			end)
		addElementOutline(btnUp)
		local btnDown = edit:dgsButton(0.6,0.5,0.4,0.5," ▼",true)
			:setProperties({
				alignment = {"center","center"},
				textSize = {0.7,0.7},
			})
			:on("dgsMouseClickDown",function()
				local arg = tonumber(source.parent:getText()) or 0
				local arg = arg - 1
				if arg < 0 then arg = 0 end
				source.parent:setText(arg)
			end)
		addElementOutline(btnDown)
		edit:setWhiteList("[^0-9]")
		edit:bindToColorPicker(dgsEditor.ColorPicker,"RGB",attr)
	end

	--HSL edits
	local HSL = {"H","S","L"}
	for i, attr in pairs(HSL) do
		dgsEditor.WidgetColorMain:dgsLabel(115,190+i*30-30,0,20,attr..":",false)
			:setProperty("alignment",{"right","center"})

		local edit = dgsEditor.WidgetColorMain:dgsEdit(120,190+i*30-30,50,20,"",false)
			:on("dgsTextChange",function()
				if attr == "H" then
					if source:getText() == "" then return end
					if tonumber(source:getText()) > 360 then return source:setText("360") end
				else
					if source:getText() == "" then return end
					if tonumber(source:getText()) > 100 then return source:setText("100") end
				end
			end)
		addElementOutline(edit)
		local btnUp = edit:dgsButton(0.6,0,0.4,0.5," ▲",true)
			:setProperties({
				alignment = {"center","center"},
				textSize = {0.7,0.7},
			})
			:on("dgsMouseClickDown",function()
				local arg = tonumber(source.parent:getText()) or 0
				local arg = arg + 1
				if attr == "H" then
					if arg > 360 then arg = 360 end
				else
					if arg > 100 then arg = 100 end
				end
				source.parent:setText(arg)
			end)
		addElementOutline(btnUp)
		local btnDown = edit:dgsButton(0.6,0.5,0.4,0.5," ▼",true)
			:setProperties({
				alignment = {"center","center"},
				textSize = {0.7,0.7},
			})
			:on("dgsMouseClickDown",function()
				local arg = tonumber(source.parent:getText()) or 0
				local arg = arg - 1
				if arg < 0 then arg = 0 end
				source.parent:setText(arg)
			end)
		addElementOutline(btnDown)
		edit:setWhiteList("[^0-9]")
		edit:bindToColorPicker(dgsEditor.ColorPicker,"HSL",attr)
		if attr ~= "H" then
			dgsEditor.WidgetColorMain:dgsLabel(175,190+i*30-30,0,20,"%",false)
				:setProperty("alignment",{"left","center"})
		end
	end

	--HSV edits
	local HSV = {"H","S","V"}
	for i, attr in pairs(HSV) do
		dgsEditor.WidgetColorMain:dgsLabel(215,190+i*30-30,0,20,attr..":",false)
			:setProperty("alignment",{"right","center"})

		local edit = dgsEditor.WidgetColorMain:dgsEdit(220,190+i*30-30,50,20,"",false)
			:on("dgsTextChange",function()
				if attr == "H" then
					if source:getText() == "" then return end
					if tonumber(source:getText()) > 360 then return source:setText("360") end
				else
					if source:getText() == "" then return end
					if tonumber(source:getText()) > 100 then return source:setText("100") end
				end
			end)
		addElementOutline(edit)
		local btnUp = edit:dgsButton(0.6,0,0.4,0.5," ▲",true)
			:setProperties({
				alignment = {"center","center"},
				textSize = {0.7,0.7},
			})
			:on("dgsMouseClickDown",function()
				local arg = tonumber(source.parent:getText()) or 0
				local arg = arg + 1
				if attr == "H" then
					if arg > 360 then arg = 360 end
				else
					if arg > 100 then arg = 100 end
				end
				source.parent:setText(arg)
			end)
		addElementOutline(btnUp)
		local btnDown = edit:dgsButton(0.6,0.5,0.4,0.5," ▼",true)
			:setProperties({
				alignment = {"center","center"},
				textSize = {0.7,0.7},
			})
			:on("dgsMouseClickDown",function()
				local arg = tonumber(source.parent:getText()) or 0
				local arg = arg - 1
				if arg < 0 then arg = 0 end
				source.parent:setText(arg)
			end)
		addElementOutline(btnDown)
		edit:setWhiteList("[^0-9]")
		edit:bindToColorPicker(dgsEditor.ColorPicker,"HSV",attr)
		if attr ~= "H" then
			dgsEditor.WidgetColorMain:dgsLabel(275,190+i*30-30,0,20,"%",false)
				:setProperty("alignment",{"left","center"})
		end
	end

	--old/new color
	local shader = dxCreateShader("client/alphaCircle.fx")
	dxSetShaderValue(shader,"items",6)
	dxSetShaderValue(shader,"radius",1)
	local background = dgsEditor.WidgetColorMain
		:dgsImage(300,190,80,80,shader,false)
	addElementOutline(background)

	dgsEditor.WidgetColorMain:dgsLabel(300,190,80,0,"new",false)
		:setProperty("alignment",{"center","bottom"})
	local newImage = dgsEditor.WidgetColorMain
		:dgsImage(300,190,80,40,_,false,tocolor(0,0,0,255))

	dgsEditor.ColorPicker:on("dgsColorPickerChange",function()
			newImage:setProperty("color",tocolor(source:getColor()))
		end)

	dgsEditor.WidgetColorMain:dgsLabel(300,270,80,0,"old",false)
		:setProperty("alignment",{"center","top"})
	dgsEditor.ColorPicker.oldImage = dgsEditor.WidgetColorMain
		:dgsImage(300,230,80,40,_,false,tocolor(255,255,255,255))

	--confirm button
	local btn = dgsEditor.WidgetColorMain:dgsButton(10,300,80,20,"confirm",false)
		:on("dgsMouseClickUp",function()
			if dgsEditor.ColorPicker.childImage then
				local r,g,b,a = dgsEditor.ColorPicker:getColor()
				dgsCircleSetColor(dgsEditor.ColorPicker.childImage,tocolor(r,g,b,a))
			end
			dgsEditor.WidgetColorMain.visible = false
			dgsEditor.ColorPicker.childImage = nil
		end)
	addElementOutline(btn)

	--cancel button
	local btn = dgsEditor.WidgetColorMain:dgsButton(300,300,80,20,"cancel",false)
		:on("dgsMouseClickUp",function()
			dgsEditor.WidgetColorMain.visible = false
			dgsEditor.ColorPicker.childImage = nil
		end)
	addElementOutline(btn)
			
	dgsEditor.WidgetColorMain.visible = false
	--circle detect area
	dgsEditor.DA = dgsDetectArea()
		:setFunction("circle")

	--detach from color picker
	dgsEditor.BackGround:on("dgsMouseClickDown",function(button,state)
		if button == "left" then
			if dgsIsMouseWithinGUI(dgsEditor.WidgetColorMain.dgsElement) then
				return
			end
			dgsEditor.WidgetColorMain.visible = false
			dgsEditor.ColorPicker.childImage = nil
		end
	end,true)
end

----------------Generation Code Menu
function dgsEditorCreateGenerateCode()
	dgsEditor.GenerateMain  = dgsEditor.BackGround:dgsWindow(0,sH-300,300,300,"Generate Code",false)
		:setCloseButtonEnabled(false)
		:setProperties({
			shadow = {1,1,0xFF000000},
			titleColorBlur = false,
			color = tocolor(0,0,0,128),
			titleColor = tocolor(0,0,0,128),
			textSize = {1.2,1.2},
			minSize = {100,100},
			borderSize = 10,
		})

	dgsEditor.CodeMemo = dgsEditor.GenerateMain:dgsMemo(10,10,280,300-dgsEditor.GenerateMain.titleHeight-dgsEditor.GenerateMain.borderSize*2-30,"",false)
	
	local btn = dgsEditor.GenerateMain:dgsButton(300-80-dgsEditor.GenerateMain.borderSize,300-20-dgsEditor.GenerateMain.titleHeight-dgsEditor.GenerateMain.borderSize,80,20,"generate",false)
		:on("dgsMouseClickDown",function(btn,state)
			if btn == "left" and state == "down" then
				dgsEditor.CodeMemo:setText(generateCode())
			end
		end)
	--Press G to generate the code
	bindKey("G","down",function()
		btn:simulateClick("left")
	end)

	--Resize childs
	dgsEditor.GenerateMain:on("dgsSizeChange",function()
		local w,h = source:getSize()
		dgsEditor.CodeMemo:setSize(w-source.borderSize*2,h-source.titleHeight-source.borderSize*2-30)
		btn:setPosition(w-80-source.borderSize,h-20-source.titleHeight-source.borderSize)
	end)
end

----------------Hot Key Controller
KeyHolder = {}
function onClientKeyCheckInRender()
	if KeyHolder.repeatKey then
		local tick = getTickCount()
		if tick-KeyHolder.repeatStartTick >= KeyHolder.repeatDuration then
			KeyHolder.repeatStartTick = tick
			if getKeyState(KeyHolder.lastKey) then
				onClientKeyTriggered(KeyHolder.lastKey)
			else
				KeyHolder = {}
			end
		end
	end
end
addEventHandler("onClientRender",root,onClientKeyCheckInRender)

function onClientKeyCheck(button,state)
	if state and button:sub(1,5) ~= "mouse" then
		if isTimer(KeyHolder.Timer) then killTimer(KeyHolder.Timer) end
		KeyHolder = {}
		KeyHolder.lastKey = button
		KeyHolder.Timer = setTimer(function()
			if not getKeyState(KeyHolder.lastKey) then
				KeyHolder = {}
				return
			end
			KeyHolder.repeatKey = true
			KeyHolder.repeatStartTick = getTickCount()
			KeyHolder.repeatDuration = 25
		end,400,1)
		if onClientKeyTriggered(button) then
			cancelEvent()
		end
	end
end
addEventHandler("onClientKey",root,onClientKeyCheck)

function onClientKeyTriggered(button)
	--Undo/redo action
	local shift = getKeyState("lshift") or getKeyState("rshift")
	local ctrl = getKeyState("lctrl") or getKeyState("rctrl")
	if ctrl and button == "z" then
		if shift then
			if dgsEditor.ActionHistory.Redo and #dgsEditor.ActionHistory.Redo > 0 then
				historyActionState = historyActionState - 1
				local name,args = unpack(dgsEditor.ActionHistory.Redo[1])
				table.remove(dgsEditor.ActionHistory.Redo,1)
				dgsEditor.Action[name](unpack(args))
				if name == "destroy" then
					saveAction("show",args,true)
				elseif name == "show" then
					saveAction("destroy",args,true)
				elseif name == "returnProperty" then
					saveAction("cancelProperty",args,true)
				end
			end
		else
			if dgsEditor.ActionHistory.Undo and #dgsEditor.ActionHistory.Undo > 0 then
				historyActionState = historyActionState + 1
				local name,args = unpack(dgsEditor.ActionHistory.Undo[1])
				table.remove(dgsEditor.ActionHistory.Undo,1)
				dgsEditor.Action[name](unpack(args))
				if name == "destroy" then
					table.insert(dgsEditor.ActionHistory.Redo,1,{"show",args})
				elseif name == "show" then
					table.insert(dgsEditor.ActionHistory.Redo,1,{"destroy",args})
				elseif name == "cancelProperty" then
					table.insert(dgsEditor.ActionHistory.Redo,1,{"returnProperty",args})
				end
			end
		end
	end
	if dgsEditor.Controller and dgsEditor.Controller.visible then
		if button == "arrow_u" then
			dgsEditor.Controller.position = dgsEditor.Controller.position.toVector+Vector2(0,-1)
		elseif button == "arrow_d" then
			dgsEditor.Controller.position = dgsEditor.Controller.position.toVector+Vector2(0,1)
		elseif button == "arrow_l" then
			dgsEditor.Controller.position = dgsEditor.Controller.position.toVector+Vector2(-1,0)
		elseif button == "arrow_r" then
			dgsEditor.Controller.position = dgsEditor.Controller.position.toVector+Vector2(1,0)
		elseif button == "delete" then
			if dgsEditor.Controller.BoundChild then
				dgsEditorDestroyElement(dgsGetInstance(dgsEditor.Controller.BoundChild),true)
			end
		elseif button == "enter" then
			--Confirm color picker
			if dgsEditor.WidgetColorMain.visible then
				if dgsEditor.ColorPicker.childImage then
					local r,g,b,a = dgsEditor.ColorPicker:getColor()
					dgsCircleSetColor(dgsEditor.ColorPicker.childImage,tocolor(r,g,b,a))
				end
				dgsEditor.WidgetColorMain.visible = false
				dgsEditor.ColorPicker.childImage = nil
			end			
		end
	end
end

--Save property changes 
function changeProperty(element,property,newValue,i,t,type)
	if property == "noCloseButton" then
		element:setCloseButtonEnabled(newValue)
	end
	local tempValue = element[property]
	local oldValue = element[property]
	if t then
		tempValue[t][i] = newValue or tempValue[t][i]
	else
		if i then
			tempValue[i] = newValue or tempValue[i]
		else
			tempValue = newValue
		end
	end
	element[property] = tempValue
	local newValue = element[property]
	
	local tempPropertyList = element.dgsEditorPropertyList
	if not tempPropertyList then tempPropertyList = {} end
	if type == "color" then
		local r,g,b,a = fromcolor(newValue,true)
		newValue = "tocolor("..r..", "..g..", "..b..", "..a..")"
	elseif type == "quotes" then
		newValue = "\""..newValue.."\""
	end
	tempPropertyList[property] = newValue
	element.dgsEditorPropertyList = tempPropertyList
	saveAction("cancelProperty",{element,property,newValue,oldValue})
end

--Save actions
function saveAction(name,args,isAction)
	if not isAction then
		if historyActionState > 0 then
			historyActionState = 0 -- reset state
			dgsEditor.ActionHistory.Redo = {} -- clear redo actions
		end
	end
	table.insert(dgsEditor.ActionHistory.Undo,1,{name,args})
	if #dgsEditor.ActionHistory.Undo > historyLimit then
		table.remove(dgsEditor.ActionHistory.Undo,#dgsEditor.ActionHistory.Undo)
	end
end

--destroy element
function dgsEditorDestroyElement(element,isAction)
	if element then
		--if save action
		if isAction then
			saveAction("show",{element})
		end
		if element.children then
			for _, child in pairs(element.children) do
				--if it is not an internal element
				if child.isCreatedByEditor then
					child.isCreatedByEditor = false
				end
			end
		end
		element.visible = false
		element.isCreatedByEditor = false
		dgsEditorControllerDetach()
		dgsEditor.Controller.BoundChild = nil
		dgsEditor.Controller.visible = false
	end
end
-----------------------------------------------------Start up
function startup()
	loadEditorSettings()
	checkLanguages()
	setCurrentLanguage(dgsEditorSettings.UsingLanguage)
end
startup()