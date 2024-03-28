-- Название: Танцы
-- Автор: Avondale, дискорд - avonda
-- Описание механики: танцуй, нажимая набегающие пиксели
-- Идеи по доработке:
--    1. Сейчас пиксели ловятся, если просто стоять. Хотелось бы наказывать за пустые нажатия, но есть сложность с инертностью датчиков

local CLog = require("log")
local CInspect = require("inspect")
local CHelp = require("help")
local CJson = require("json")
local CTime = require("time")
local CAudio = require("audio")
local CColors = require("colors")

local tGame = {
    Cols = 24,
    Rows = 15,
    Buttons = {},
}
local tConfig = {}

-- стейты или этапы игры
local GAMESTATE_TUTORIAL = 1
local GAMESTATE_SETUP = 2
local GAMESTATE_GAME = 3
local GAMESTATE_POSTGAME = 4
local GAMESTATE_FINISH = 5

local bGamePaused = false
local iGameState = GAMESTATE_TUTORIAL
local iPrevTickTime = 0
local bAnyButtonClick = false
local tPlayerInGame = {}
local iSongStartedTime = 0
local bCountDownStarted = false

local tGameStats = {
    StageLeftDuration = 0,
    StageTotalDuration = 0,
    CurrentStars = 0,
    TotalStars = 0,
    CurrentLives = 0,
    TotalLives = 0,
    Players = { -- максимум 6 игроков
        { Score = 0, Lives = 0, Color = CColors.NONE },
        { Score = 0, Lives = 0, Color = CColors.NONE },
        { Score = 0, Lives = 0, Color = CColors.NONE },
        { Score = 0, Lives = 0, Color = CColors.NONE },
        { Score = 0, Lives = 0, Color = CColors.NONE },
        { Score = 0, Lives = 0, Color = CColors.NONE },
    },
    TargetScore = 0,
    StageNum = 0,
    TotalStages = 0,
    TargetColor = CColors.NONE,
}

local tGameResults = {
    Won = false,
}

local tFloor = {}
local tButtons = {}

local tFloorStruct = {
    iColor = CColors.NONE,
    iBright = CColors.BRIGHT0,
    bClick = false,
    bDefect = false,
    iWeight = 0,
    iPixelID = 0,
    bAnimated = false,
}
local tButtonStruct = {
    iColor = CColors.NONE,
    iBright = tConfig.Bright,
    bClick = false,
    bDefect = false,
}

function StartGame(gameJson, gameConfigJson)
    tGame = CJson.decode(gameJson)
    tConfig = CJson.decode(gameConfigJson)

    for iX = 1, tGame.Cols do
        tFloor[iX] = {}
        for iY = 1, tGame.Rows do
            tFloor[iX][iY] = CHelp.ShallowCopy(tFloorStruct)
        end
    end

    for _, iId in pairs(tGame.Buttons) do
        tButtons[iId] = CHelp.ShallowCopy(tButtonStruct)
        tButtons[iId].iColor = CColors.BLUE
        tButtons[iId].iBright = CColors.BRIGHT70
    end

    local err = CAudio.PreloadFile(tGame["SongName"])
    if err ~= nil then error(err); end

    CAudio.PlaySync("voices/press-button-for-start.mp3")
end

function NextTick()
    if iGameState == GAMESTATE_TUTORIAL then
        TutorialTick()
    end

    if iGameState == GAMESTATE_SETUP then
        GameSetupTick()
    end

    if iGameState == GAMESTATE_GAME then
        GameTick()
    end

    if iGameState == GAMESTATE_POSTGAME then
        PostGameTick()
    end

    if iGameState == GAMESTATE_FINISH then
        return tGameResults
    end

    CSongSync.Count((CTime.unix() - iSongStartedTime) * 1000 - tConfig.SongStartDelayMS)

    CTimer.CountTimers((CTime.unix() - iPrevTickTime) * 1000)

    iPrevTickTime = CTime.unix()
end

function TutorialTick()
    if bAnyButtonClick then
        bAnyButtonClick = false

        if not CTutorial.bStarted then
            CTutorial.Start()
        else
            CTutorial.Skip()
        end

        return;
    end

    if CTutorial.bStarted and CSongSync.bOn then
        GameTick()
        SetAllButtonsColorBright(CColors.BLUE, tConfig.Bright)
    end
end

function GameSetupTick()
    SetGlobalColorBright(CColors.NONE, tConfig.Bright) -- красим всё поле в один цвет
    SetAllButtonsColorBright(CColors.BLUE, tConfig.Bright)

    local iPlayersReady = 0

    for iPos, tPos in ipairs(tGame.StartPositions) do
        if iPos <= #tGame.StartPositions then

            local iBright = CColors.BRIGHT15
            if CheckPositionClick({X = tPos.X, Y = tPos.Y-1}, tGame.StartPositionSize) or (bCountDownStarted and tPlayerInGame[iPos]) then
                tGameStats.Players[iPos].Color = tPos.Color
                iBright = tConfig.Bright
                iPlayersReady = iPlayersReady + 1
                tPlayerInGame[iPos] = true
            else
                tGameStats.Players[iPos].Color = CColors.NONE
                tPlayerInGame[iPos] = false
            end

            CPaint.PlayerZone(iPos, iBright)
        end
    end

    if not bCountDownStarted and iPlayersReady > 0 and bAnyButtonClick then
        CTimer.tTimers = {}

        --iGameState = GAMESTATE_GAME
        bCountDownStarted = true
        CGameMode.CountDown(5)
    end
end

function GameTick()
    SetGlobalColorBright(CColors.NONE, tConfig.Bright) -- красим всё поле в один цвет
    CPaint.Borders()
    CPaint.PlayerZones()
    CPaint.Pixels() -- красим движущиеся пиксели
end

function PostGameTick()
    SetGlobalColorBright(tGameStats.Players[CGameMode.iWinnerID].Color, tConfig.Bright)
end

function RangeFloor(setPixel, setButton)
    for iX = 1, tGame.Cols do
        for iY = 1, tGame.Rows do
            setPixel(iX , iY, tFloor[iX][iY].iColor, tFloor[iX][iY].iBright)
        end
    end

    for i, tButton in pairs(tButtons) do
        setButton(i, tButton.iColor, tConfig.Bright)
    end
end

function SwitchStage()

end

--TUTORIAL
CTutorial = {}
CTutorial.bStarted = false

CTutorial.Start = function()
    CTutorial.bStarted = true
    CAudio.PlaySyncFromScratch("") -- обрыв звука
    CAudio.PlaySync("dance/how_to_play.mp3") 

    CGameMode.PixelMovement()
    CSongSync.Start(tTutorialSong)
end

CTutorial.Skip = function()
    CSongSync.Clear()
    CGameMode.Clear()
    CAudio.PlaySyncFromScratch("") -- обрыв звука

    CAudio.PlaySync("voices/choose-color.mp3")
    iGameState = GAMESTATE_SETUP
end
--//

--SONGSYNC
CSongSync = {}
CSongSync.iTime = 0
CSongSync.iSongPoint = 1
CSongSync.bOn = false
CSongSync.tSong = {}

CSongSync.Start = function(tSong)
    CSongSync.bOn = true
    CSongSync.tSong = tSong
    CSongSync.iTime = 0
    CSongSync.iSongPoint = 1
    tGameStats.TargetScore = 0

    for i = 1, #CSongSync.tSong do
        if CSongSync.tSong[i] then
            CSongSync.tSong[i][1] = CSongSync.tSong[i][1] - (tConfig.PixelMoveDelayMS * (tGame.Rows - tGame.StartPositions[1].Y))

            --[[
            for j = 2, #CSongSync.tSong[i] do
                if CSongSync.tSong[i][j] then
                    tGameStats.TargetScore = tGameStats.TargetScore + 1
                end
            end
            ]]
        end
    end

    CAudio.PlaySync(tGame["SongName"])
    iSongStartedTime = CTime.unix()
end

CSongSync.Clear = function()
    CSongSync.bOn = false
    CSongSync.tSong = {}
    CSongSync.iTime = 0
    CSongSync.iSongPoint = 0   
end

CSongSync.Count = function(iTimePassed)
    if (not CSongSync.bOn) or (iGameState ~= GAMESTATE_GAME and iGameState ~= GAMESTATE_TUTORIAL) then return; end
    for i = 1, #CSongSync.tSong do
        if CSongSync.tSong[i] ~= nil then
            if CSongSync.tSong[i][1] - iTimePassed <= 0 then
                local iBatchID = math.random(1,999)
                local iPos = 0
                for j = 2, #CSongSync.tSong[i] do
                    iPos = iPos + 1
                    CGameMode.SpawnPixelForPlayers(iPos, iBatchID, CSongSync.tSong[i][j])
                end

                if i == #CSongSync.tSong then
                    if iGameState == GAMESTATE_TUTORIAL then
                        CTimer.New(5000, function()
                            CTutorial.Skip()
                        end)
                    else 
                        CTimer.New(5000, function()
                            CGameMode.EndGame()
                        end)
                    end
                end

                CSongSync.tSong[i] = nil
            end
        end
    end
end
--//

--GAMEMODE
CGameMode = {}
CGameMode.iCountdown = -1
CGameMode.iWinnerID = -1
CGameMode.tPixels = {}
CGameMode.tPixelStruct = {
    iPointX = 0,
    iPointY = 0,
    iColor = CColors.GREEN,
    iBright = CColors.BRIGHT50,
    iPlayerID = 0,
    bClickable = true,
    bProlong = false,
    bVisual = false,
    iBatchID = 0,
}
CGameMode.tPlayerPixelBatches = {}
CGameMode.tPlayerRowClick = {}

CGameMode.CountDown = function(iCountDownTime)
    CSongSync.Clear()
    CGameMode.Clear()

    CGameMode.iCountdown = iCountDownTime

    CAudio.PlaySyncFromScratch("")
    CTimer.New(1000, function()
        tGameStats.StageLeftDuration = CGameMode.iCountdown

        if CGameMode.iCountdown <= 0 then
            CGameMode.iCountdown = -1

            iGameState = GAMESTATE_GAME

            CGameMode.PixelMovement()
            CSongSync.Start(tGame["Song"])

            return nil
        else
            CAudio.PlayLeftAudio(CGameMode.iCountdown)
            CGameMode.iCountdown = CGameMode.iCountdown - 1

            return 1000
        end
    end)
end

CGameMode.PixelMovement = function()
    CTimer.New(tConfig.PixelMoveDelayMS, function()
        if iGameState ~= GAMESTATE_GAME and iGameState ~= GAMESTATE_TUTORIAL then return nil end

        for i = 1, #CGameMode.tPixels do
            if CGameMode.tPixels[i] ~= nil then
                CGameMode.MovePixel(i)
                CGameMode.CalculatePixel(i)
            end
        end

        if iGameState == GAMESTATE_TUTORIAL then -- в туториале пиксели падают медленее
            return math.floor(tConfig.PixelMoveDelayMS * 1.5)
        end

        return tConfig.PixelMoveDelayMS
    end)
end

CGameMode.MovePixel = function(iPixelID)
    if CGameMode.tPixels[iPixelID].iPointY < 1 then return; end

    if not CGameMode.tPixels[iPixelID].bProlong then
        tFloor[CGameMode.tPixels[iPixelID].iPointX][CGameMode.tPixels[iPixelID].iPointY].iPixelID = 0
    end

    CGameMode.tPixels[iPixelID].iPointY = CGameMode.tPixels[iPixelID].iPointY - 1

    if CGameMode.tPixels[iPixelID].iPointY > 0 then
        tFloor[CGameMode.tPixels[iPixelID].iPointX][CGameMode.tPixels[iPixelID].iPointY].iPixelID = iPixelID
    end
end

CGameMode.CalculatePixel = function(iPixelID)
    if CGameMode.tPixels[iPixelID] == nil then return; end

    local iPlayerID = CGameMode.tPixels[iPixelID].iPlayerID

    if CGameMode.tPixels[iPixelID].iPointY <= tGame.StartPositions[iPlayerID].Y then
        CGameMode.tPixels[iPixelID].iBright = CColors.BRIGHT100

        if CGameMode.tPixels[iPixelID].iPointY == 0 then
            if CGameMode.tPixels[iPixelID].bVisual then CGameMode.tPixels[iPixelID] = nil return; end

            if CGameMode.tPlayerPixelBatches[iPlayerID][CGameMode.tPixels[iPixelID].iBatchID] then
                CGameMode.tPlayerPixelBatches[iPlayerID][CGameMode.tPixels[iPixelID].iBatchID] = false
                CPaint.AnimateRow(tGame.StartPositions[iPlayerID].X - 1, CColors.RED)
                CPaint.AnimateRow(tGame.StartPositions[iPlayerID].X + tGame.StartPositionSize, CColors.RED)
            end

            if CGameMode.tPixels[iPixelID].bProlong then
                CGameMode.tPixels[iPixelID].iPointY = -1
            else
                CGameMode.tPixels[iPixelID] = nil
            end
        else
            CGameMode.PlayerHitRow(CGameMode.tPixels[iPixelID].iPointX, CGameMode.tPixels[iPixelID].iPointY)
        end
    end
end

CGameMode.PlayerHitRow = function(iX, iY)
    if iY <= tGame.StartPositions[1].Y and iY > 0 then
        local bClickAny = false
        for iY1 = 1, tGame.StartPositions[1].Y do
            if tFloor[iX][iY1].bClick then
                bClickAny = true
            end
        end

        if bClickAny then
            for iY2 = 1, tGame.StartPositions[1].Y do
                if tFloor[iX][iY2].iPixelID and CGameMode.tPixels[tFloor[iX][iY2].iPixelID] and CGameMode.tPixels[tFloor[iX][iY2].iPixelID].bClickable then
                    CGameMode.ScorePixel(tFloor[iX][iY2].iPixelID)
                end
            end
        end
    end
end

CGameMode.ScorePixel = function(iPixelID)
    if CGameMode.tPixels[iPixelID].bVisual then return; end
    if not CGameMode.tPixels[iPixelID].bClickable then return; end
    CGameMode.tPixels[iPixelID].bClickable = false

    local iPlayerID = CGameMode.tPixels[iPixelID].iPlayerID

    if iGameState == GAMESTATE_GAME then
        tGameStats.Players[iPlayerID].Score = tGameStats.Players[iPlayerID].Score + 1

        if tGameStats.Players[iPlayerID].Score > tGameStats.TargetScore then
            tGameStats.TargetScore = tGameStats.Players[iPlayerID].Score
        end
    end

    if CGameMode.tPlayerPixelBatches[iPlayerID][CGameMode.tPixels[iPixelID].iBatchID] == true then
        CPaint.AnimateRow(tGame.StartPositions[iPlayerID].X - 1, CColors.GREEN)
        CPaint.AnimateRow(tGame.StartPositions[iPlayerID].X + tGame.StartPositionSize, CColors.GREEN)
    end

    if not CGameMode.tPixels[iPixelID].bProlong then
        for iY = 1, tGame.StartPositions[iPlayerID].Y do
            tFloor[CGameMode.tPixels[iPixelID].iPointX][iY].iPixelID = 0
        end

        CGameMode.tPixels[iPixelID] = nil
    end
end

CGameMode.SpawnPixelForPlayers = function(iPointX, iBatchID, iPixelType)
    for i = 1, #tGame.StartPositions do
        if tPlayerInGame[i] or iGameState == GAMESTATE_TUTORIAL then
            CGameMode.SpawnPixelForPlayer(i, iPointX, iBatchID, iPixelType)
        end
    end
end

CGameMode.SpawnPixelForPlayer = function(iPlayerID, iPointX, iBatchID, iPixelType)
    if iPixelType == "N" then return; end

    iPointX = tGame.StartPositions[iPlayerID].X + 4 - iPointX
    local iPixelID = #CGameMode.tPixels+1

    CGameMode.tPixels[iPixelID] = CHelp.ShallowCopy(CGameMode.tPixelStruct)
    CGameMode.tPixels[iPixelID].iPointX = iPointX
    CGameMode.tPixels[iPixelID].iPointY = tGame.Rows
    CGameMode.tPixels[iPixelID].iPlayerID = iPlayerID
    CGameMode.tPixels[iPixelID].iBright = tConfig.Bright
    CGameMode.tPixels[iPixelID].bClickable = true
    CGameMode.tPixels[iPixelID].iBatchID = iBatchID

    if string.match(iPixelType, "L") and not tConfig.EasyMode then
        CGameMode.tPixels[iPixelID].iColor = CColors.GREEN
    elseif string.match(iPixelType, "R")  and not tConfig.EasyMode then
        CGameMode.tPixels[iPixelID].iColor = CColors.YELLOW
    elseif string.match(iPixelType, "H") then
        CGameMode.tPixels[iPixelID].iColor = CColors.BLUE
    end

    CGameMode.tPixels[iPixelID].bProlong = string.match(iPixelType, "P") --and not tConfig.EasyMode
    CGameMode.tPixels[iPixelID].bVisual = string.match(iPixelType, "H")

    if CGameMode.tPlayerPixelBatches[iPlayerID] == nil then CGameMode.tPlayerPixelBatches[iPlayerID] = {} end
    CGameMode.tPlayerPixelBatches[iPlayerID][iBatchID] = true
end

CGameMode.EndGame = function()
    local iMaxScore = -1

    for i = 1, #tGame.StartPositions do
        if tPlayerInGame[i] and tGameStats.Players[i] and tGameStats.Players[i].Score > iMaxScore then
            iMaxScore = tGameStats.Players[i].Score
            CGameMode.iWinnerID = i
        end
    end

    CPaint.ClearAnimations()
    --CPaint.AnimateEnd(tGameStats.Players[CGameMode.iWinnerID].Color)
    iGameState = GAMESTATE_POSTGAME
    CAudio.PlaySyncFromScratch("")
    CAudio.PlaySyncColorSound(tGameStats.Players[CGameMode.iWinnerID].Color)
    CAudio.PlaySync(CAudio.VICTORY)

    CTimer.New(tConfig.WinDurationMS, function()
        iGameState = GAMESTATE_FINISH
    end)
end

CGameMode.Clear = function()
    CGameMode.tPixels = {}
    CGameMode.tPlayerPixelBatches = {}
    CGameMode.tPlayerRowClick = {}    
end
--//

--PAINT
CPaint = {}
CPaint.ANIMATE_DELAY = 50

CPaint.Borders = function()
    for i = 1, #tGame.StartPositions do
        if tPlayerInGame[i] or iGameState == GAMESTATE_TUTORIAL then
            local iColor = CColors.WHITE
            SetRowColorBright(tGame.StartPositions[i].X-1, tGame.Rows, iColor, CColors.BRIGHT70)
            SetRowColorBright(tGame.StartPositions[i].X+tGame.StartPositionSize, tGame.Rows, iColor, CColors.BRIGHT70)
        end
    end
end

CPaint.Pixels = function()
    for iX = 1, tGame.Cols do
        for iY = 1, tGame.Rows do
            if tFloor[iX][iY] and tFloor[iX][iY].iPixelID and CGameMode.tPixels[tFloor[iX][iY].iPixelID] ~= nil then
                tFloor[iX][iY].iColor = CGameMode.tPixels[tFloor[iX][iY].iPixelID].iColor
                tFloor[iX][iY].iBright = CGameMode.tPixels[tFloor[iX][iY].iPixelID].iBright
            end
        end
    end

    --[[
    for i = 1, #CGameMode.tPixels do
        if CGameMode.tPixels[i] then
            tFloor[CGameMode.tPixels[i].iPointX][CGameMode.tPixels[i].iPointY].iColor = CGameMode.tPixels[i].iColor
            tFloor[CGameMode.tPixels[i].iPointX][CGameMode.tPixels[i].iPointY].iBright = CGameMode.tPixels[i].iBright
        end
    end
    ]]
end

CPaint.PlayerZone = function(iPlayerID, iBright)
    SetColColorBright(tGame.StartPositions[iPlayerID], tGame.StartPositionSize-1, tGame.StartPositions[iPlayerID].Color, iBright)
    SetColColorBright({X = tGame.StartPositions[iPlayerID].X+1, Y = tGame.StartPositions[iPlayerID].Y-1,}, tGame.StartPositionSize-3, tGame.StartPositions[iPlayerID].Color, iBright)
end

CPaint.PlayerZones = function()
    for i = 1, #tGame.StartPositions do
        if tPlayerInGame[i] or iGameState == GAMESTATE_TUTORIAL then
            CPaint.PlayerZone(i, CColors.BRIGHT15)
        end
    end
end

CPaint.AnimateRow = function(iX, iColor)
    for iY = 1, tGame.Rows do
        tFloor[iX][iY].iColor = iColor
        tFloor[iX][iY].iBright = tConfig.Bright
        tFloor[iX][iY].bAnimated = true
    end

    CTimer.New(tConfig.PixelMoveDelayMS, function()
        for iY = 1, tGame.Rows do
            tFloor[iX][iY].bAnimated = false
        end
    end)
end

CPaint.ClearAnimations = function()
    for iX = 1, tGame.Cols do
        for iY = 1, tGame.Rows do
            tFloor[iX][iY].bAnimated = false
        end
    end
end
--//

--TIMER класс отвечает за таймеры, очень полезная штука. можно вернуть время нового таймера с тем же колбеком
CTimer = {}
CTimer.tTimers = {}

CTimer.New = function(iSetTime, fCallback)
    CTimer.tTimers[#CTimer.tTimers+1] = {iTime = iSetTime, fCallback = fCallback}
end

-- просчёт таймеров каждый тик
CTimer.CountTimers = function(iTimePassed)
    for i = 1, #CTimer.tTimers do
        if CTimer.tTimers[i] ~= nil then
            CTimer.tTimers[i].iTime = CTimer.tTimers[i].iTime - iTimePassed

            if CTimer.tTimers[i].iTime <= 0 then
                iNewTime = CTimer.tTimers[i].fCallback()
                if iNewTime and iNewTime ~= nil then -- если в return было число то создаём новый таймер с тем же колбеком
                    iNewTime = iNewTime + CTimer.tTimers[i].iTime
                    CTimer.New(iNewTime, CTimer.tTimers[i].fCallback)
                end

                CTimer.tTimers[i] = nil
            end
        end
    end
end
--//

--UTIL прочие утилиты
function CheckPositionClick(tStart, iSize)
    for i = 0, iSize * iSize - 1 do
        local iX = tStart.X + i % iSize
        local iY = tStart.Y + math.floor(i/iSize)

        if not (iX < 1 or iX > tGame.Cols or iY < 1 or iY > tGame.Rows) then
            if tFloor[iX][iY].bClick then
                return true
            end
        end
    end

    return false
end

function SetPositionColorBright(tStart, iSize, iColor, iBright)
    for i = 0, iSize * iSize - 1 do
        local iX = tStart.X + i % iSize
        local iY = tStart.Y + math.floor(i / iSize)

        if not (iX < 1 or iX > tGame.Cols or iY < 1 or iY > tGame.Rows) and not tFloor[iX][iY].bAnimated then
            tFloor[iX][iY].iColor = iColor
            tFloor[iX][iY].iBright = iBright
        end
    end
end

function SetRowColorBright(tStart, iSize, iColor, iBright)
    for i = 0, iSize do
        local iX = tStart
        local iY = 1 + i

        if not (iY < 1 or iY > tGame.Rows) and not tFloor[iX][iY].bAnimated then
            tFloor[iX][iY].iColor = iColor
            tFloor[iX][iY].iBright = iBright
        end
    end
end

function SetAllButtonsColorBright(iColor, iBright)
    for i, tButton in pairs(tButtons) do
        if not tButtons[i].bDefect then
            tButtons[i].iColor = iColor
            tButtons[i].iBright = iBright
        end
    end
end

function SetColColorBright(tStart, iSize, iColor, iBright)
    for i = 0, iSize do
        local iX = tStart.X + i
        local iY = tStart.Y

        if not (iX < 1 or iX > tGame.Cols) and not tFloor[iX][iY].bAnimated then
            tFloor[iX][iY].iColor = iColor
            tFloor[iX][iY].iBright = iBright
        end
    end
end

function SetGlobalColorBright(iColor, iBright)
    for iX = 1, tGame.Cols do
        for iY = 1, tGame.Rows do
            if not tFloor[iX][iY].bAnimated then
                tFloor[iX][iY].iColor = iColor
                tFloor[iX][iY].iBright = iBright
            end
        end
    end

    for i, tButton in pairs(tButtons) do
        if not tButtons[i].bDefect then
            tButtons[i].iColor = iColor
            tButtons[i].iBright = iBright
        end
    end
end
--//


--//
function GetStats()
    return tGameStats
end

function PauseGame()
    bGamePaused = true
end

function ResumeGame()
    bGamePaused = false
end

function PixelClick(click)
    tFloor[click.X][click.Y].bClick = click.Click
    tFloor[click.X][click.Y].iWeight = click.Weight

    if click.Click then
        CGameMode.PlayerHitRow(click.X, click.Y)
    end
end

function DefectPixel(defect)
    tFloor[defect.X][defect.Y].bDefect = defect.Defect
end

function ButtonClick(click)
    if tButtons[click.Button] == nil then return end
    tButtons[click.Button].bClick = click.Click

    if iGameState <= GAMESTATE_SETUP and click.Click == true then
        bAnyButtonClick = true
    end
end

function DefectButton(defect)
    if tButtons[defect.Button] == nil then return end
    tButtons[defect.Button].bDefect = defect.Defect

    if defect then
        tButtons[defect.Button].iColor = CColors.NONE
        tButtons[defect.Button].iBright = CColors.BRIGHT0
    end
end


-----------------------------------------------------------

tTutorialSong = 
{
    { 30000, "N", "N", "N", "N" },
    { 30500, "N", "N", "N", "N" },
    { 31000, "N", "N", "N", "N" },
    { 31500, "N", "N", "N", "N" },
    { 32000, "L", "N", "N", "N" },
    { 32500, "N", "N", "N", "N" },
    { 33000, "N", "N", "N", "N" },
    { 33500, "N", "N", "N", "N" },
    { 34000, "N", "R", "N", "N" },
    { 34500, "N", "N", "N", "N" },
    { 35000, "N", "N", "N", "N" },
    { 35500, "N", "N", "N", "N" },
    { 36000, "N", "N", "L", "N" },
    { 36500, "N", "N", "N", "N" },
    { 37000, "N", "N", "N", "N" },
    { 37500, "N", "N", "N", "N" },
    { 38000, "N", "N", "N", "R" },
    { 38500, "N", "N", "N", "N" },
    { 39000, "N", "N", "N", "N" },
    { 39500, "N", "N", "N", "N" },
    { 40000, "N", "N", "L", "N" },
    { 40500, "N", "N", "N", "N" },
    { 41000, "N", "N", "N", "N" },
    { 41500, "N", "N", "N", "N" },
    { 42000, "N", "R", "N", "N" },
    { 42500, "N", "N", "N", "N" },
    { 43000, "N", "N", "N", "N" },
    { 43500, "N", "N", "N", "N" },
    { 44000, "L", "N", "N", "N" },
    { 44500, "N", "R", "N", "N" },
    { 45000, "L", "N", "N", "N" },
    { 45500, "N", "R", "N", "N" },
    { 46000, "N", "N", "L", "N" },
    { 46500, "N", "N", "N", "R" },
    { 47000, "N", "N", "L", "N" },
    { 47500, "N", "N", "N", "R" },
    { 48000, "N", "N", "N", "N" },
    { 48500, "N", "L", "R", "N" },
    { 49000, "L", "R", "N", "N" },
    { 49500, "N", "L", "R", "N" },
    { 50000, "N", "N", "L", "R" },
    { 50500, "N", "L", "R", "N" },
    { 51000, "L", "R", "N", "N" },
    { 51500, "N", "N", "N", "N" },
    { 52000, "N", "N", "N", "N" },
    { 52500, "N", "N", "N", "N" },
    { 66000, "N", "N", "N", "N" },
    { 66500, "LP", "N", "N", "N" },
    { 67000, "LP", "N", "N", "N" },
    { 67500, "LP", "N", "N", "N" },
    { 68000, "LP", "N", "N", "N" },
    { 68500, "LP", "N", "N", "N" },
    { 69000, "L", "N", "N", "N" },
    { 69500, "N", "N", "RP", "N" },
    { 70000, "N", "N", "RP", "N" },
    { 70500, "N", "N", "RP", "N" },
    { 71000, "N", "N", "RP", "N" },
    { 71500, "N", "N", "RP", "N" },
    { 72000, "N", "N", "R", "N" },
    { 72500, "N", "LP", "N", "N" },
    { 73000, "N", "LP", "R", "N" },
    { 73500, "N", "LP", "N", "N" },
    { 74000, "N", "LP", "R", "N" },
    { 74500, "N", "LP", "N", "N" },
    { 75000, "N", "LP", "R", "N" },
    { 75500, "N", "L", "N", "N" },
    { 76000, "N", "N", "N", "N" },
    { 76500, "N", "L", "RP", "N" },
    { 77000, "N", "N", "RP", "N" },
    { 77500, "N", "L", "RP", "N" },
    { 78000, "N", "N", "RP", "N" },
    { 78500, "N", "L", "RP", "N" },
    { 79000, "N", "N", "R", "N" },
    { 79500, "N", "N", "N", "N" },
    { 86000, "N", "N", "N", "N" },
    { 86500, "L", "N", "N", "N" },
    { 87000, "N", "N", "N", "N" },
    { 87500, "N", "R", "N", "N" },
    { 88000, "N", "N", "N", "N" },
    { 88500, "N", "N", "L", "N" },
    { 89000, "N", "N", "N", "N" },
    { 89500, "N", "N", "N", "R" },
    { 90000, "N", "N", "N", "N" },
    { 90500, "H", "H", "H", "H" },
    { 91000, "N", "N", "N", "N" },
    { 91500, "N", "N", "L", "N" },
    { 92000, "N", "N", "N", "N" },
    { 92500, "N", "R", "N", "N" },
    { 93000, "N", "N", "N", "N" },
    { 93500, "L", "N", "N", "N" },
    { 94000, "N", "N", "N", "N" },
    { 94500, "H", "H", "H", "H" },
    { 95000, "N", "N", "N", "N" },
    { 95500, "N", "N", "N", "N" },
    { 96000, "N", "N", "N", "N" },
    { 96500, "N", "N", "N", "N" },
    { 97000, "N", "N", "N", "N" },
    { 105500, "N", "N", "N", "N" }
}
