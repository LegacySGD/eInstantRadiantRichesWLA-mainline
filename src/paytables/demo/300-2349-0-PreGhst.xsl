<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:x="anything">
	<xsl:namespace-alias stylesheet-prefix="x" result-prefix="xsl" />
	<xsl:output encoding="UTF-8" indent="yes" method="xml" />
	<xsl:include href="../utils.xsl" />

	<xsl:template match="/Paytable">
		<x:stylesheet version="1.0" xmlns:java="http://xml.apache.org/xslt/java" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			exclude-result-prefixes="java" xmlns:lxslt="http://xml.apache.org/xslt" xmlns:my-ext="ext1" extension-element-prefixes="my-ext">
			<x:import href="HTML-CCFR.xsl" />
			<x:output indent="no" method="xml" omit-xml-declaration="yes" />

			<!-- TEMPLATE Match: -->
			<x:template match="/">
				<x:apply-templates select="*" />
				<x:apply-templates select="/output/root[position()=last()]" mode="last" />
				<br />
			</x:template>

			<!--The component and its script are in the lxslt namespace and define the implementation of the extension. -->
			<lxslt:component prefix="my-ext" functions="formatJson,retrievePrizeTable,getType">
				<lxslt:script lang="javascript">
					<![CDATA[
					var debugFeed = [];
					var debugFlag = false;
					// Format instant win JSON results.
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function formatJson(jsonContext, translations, prizeTable, prizeValues, prizeNamesDesc)
					{
						var scenario             = getScenario(jsonContext);
						var scenarioGrids        = scenario.split('|');
						var convertedPrizeValues = (prizeValues.substring(1)).split('|').map(function(item) {return item.replace(/\t|\r|\n/gm, "")} );
						var prizeNames           = (prizeNamesDesc.substring(1)).split(',');

						////////////////////
						// Parse scenario //
						////////////////////

						const keySymbs   = ['NM','B'];
						const mgBonusQty = 3;

						var arrGrids = [];

						var arrGridParts       = [];
						var arrWinNumSet       = [];
						var arrWinNums         = [];
						var arrYourNum         = [];
						var arrYourNumRowParts = [];
						var arrYourNums        = [];
						var objGrid            = {};
						var objWinNum          = {};
						var objYourNum         = {};
						var objYourNumRow      = {};
						var winNumIndex  	   = -1;
						var winNumVal          = 0;
						var yourNumVal         = 0;
						var bonusSymbQty       = 0;
						var hasWins            = false;

						for (var gridIndex = 0; gridIndex < scenarioGrids.length - 1; gridIndex++)
						{
							objGrid      = {iMegaMulti: 0, aoWinNums: [], aoYourNumRows: []};
							arrWinNumSet = [];

							arrGridParts = scenarioGrids[gridIndex].split(';');

							objGrid.iMegaMulti = parseInt(arrGridParts[0], 10);

							arrWinNums         = arrGridParts[1].split(',');
							arrYourNumRowParts = arrGridParts.slice(2);

							for (var winNumIndex = 0; winNumIndex < arrWinNums.length; winNumIndex++)
							{
								objWinNum = {iValue: 0, bMatched: false};

								winNumVal = parseInt(arrWinNums[winNumIndex], 10);

								objWinNum.iValue = winNumVal;

								objGrid.aoWinNums.push(objWinNum);

								arrWinNumSet.push(winNumVal);
							}

							for (var yourNumRowPartIndex = 0; yourNumRowPartIndex < arrYourNumRowParts.length / 2; yourNumRowPartIndex++)
							{
								objYourNumRow = {aoYourNums: [], iRowMulti: 0, bYourNumRowWin: false};

								objYourNumRow.iRowMulti = parseInt(arrYourNumRowParts[yourNumRowPartIndex * 2 + 1], 10);

								arrYourNums = arrYourNumRowParts[yourNumRowPartIndex * 2].split(',');

								for (var yourNumIndex = 0; yourNumIndex < arrYourNums.length; yourNumIndex++)
								{
									objYourNum = {iValue: 0, sPrize: '', bMatched: false, bBonusSymb: false};

									if (arrYourNums[yourNumIndex] == 'B')
									{
										objYourNum.bBonusSymb = true;

										bonusSymbQty++;
									}
									else
									{
										arrYourNum = arrYourNums[yourNumIndex].split(':');

										yourNumVal = parseInt(arrYourNum[0], 10);

										objYourNum.iValue = yourNumVal;
										objYourNum.sPrize = arrYourNum[1];

										winNumIndex = arrWinNumSet.indexOf(yourNumVal);

										if (winNumIndex != -1)
										{
											objYourNum.bMatched = true;
											objYourNumRow.bYourNumRowWin = true;
											objGrid.aoWinNums[winNumIndex].bMatched = true;
											hasWins = true;
										}
									}

									objYourNumRow.aoYourNums.push(objYourNum);
								}

								objGrid.aoYourNumRows.push(objYourNumRow);
							}

							arrGrids.push(objGrid);
						}

						/////////////////////////
						// Currency formatting //
						/////////////////////////

						var bCurrSymbAtFront = false;
						var strCurrSymb      = '';
						var strDecSymb       = '';
						var strThouSymb      = '';

						function getCurrencyInfoFromTopPrize()
						{
							var topPrize               = convertedPrizeValues[0];
							var strPrizeAsDigits       = topPrize.replace(new RegExp('[^0-9]', 'g'), '');
							var iPosFirstDigit         = topPrize.indexOf(strPrizeAsDigits[0]);
							var iPosLastDigit          = topPrize.lastIndexOf(strPrizeAsDigits.substr(-1));
							bCurrSymbAtFront           = (iPosFirstDigit != 0);
							strCurrSymb 	           = (bCurrSymbAtFront) ? topPrize.substr(0,iPosFirstDigit) : topPrize.substr(iPosLastDigit+1);
							var strPrizeNoCurrency     = topPrize.replace(new RegExp('[' + strCurrSymb + ']', 'g'), '');
							var strPrizeNoDigitsOrCurr = strPrizeNoCurrency.replace(new RegExp('[0-9]', 'g'), '');
							strDecSymb                 = strPrizeNoDigitsOrCurr.substr(-1);
							strThouSymb                = (strPrizeNoDigitsOrCurr.length > 1) ? strPrizeNoDigitsOrCurr[0] : strThouSymb;
						}

						function getPrizeInCents(AA_strPrize)
						{
							return parseInt(AA_strPrize.replace(new RegExp('[^0-9]', 'g'), ''), 10);
						}

						function getCentsInCurr(AA_iPrize)
						{
							var strValue = AA_iPrize.toString();

							strValue = (strValue.length < 3) ? ('00' + strValue).substr(-3) : strValue;
							strValue = strValue.substr(0,strValue.length-2) + strDecSymb + strValue.substr(-2);
							strValue = (strValue.length > 6) ? strValue.substr(0,strValue.length-6) + strThouSymb + strValue.substr(-6) : strValue;
							strValue = (bCurrSymbAtFront) ? strCurrSymb + strValue : strValue + strCurrSymb;

							return strValue;
						}

						getCurrencyInfoFromTopPrize();

						///////////////
						// UI Config //
						///////////////

						const boxWidthKey   = 30;
						const boxWidthNum   = 60;
						const boxWidthPrize = 120;
						
						const colourBlack   = '#000000';
						const colourLemon   = '#ffff99';
						const colourLime    = '#ccff99';						
						const colourOrange  = '#ffaa55';
						const colourRed     = '#ff9999';						
						const colourScarlet = '#ff0000';
						const colourWhite   = '#ffffff';
						const colourYellow  = '#ffff00';

						const specialBoxColours  = [colourLime, colourScarlet];
						const specialTextColours = [colourBlack, colourYellow];

						var canvasIdStr   = '';
						var elementStr    = '';
						var boxColourStr  = '';
						var textColourStr = '';
						var textStr1      = '';
						var textStr2      = '';

						var r = [];

						function showBox(A_strCanvasId, A_strCanvasElement, A_iBoxWidth, A_strBoxColour, A_strTextColour, A_strText1, A_strText2)
						{
							const boxHeightStd = 24;
							const boxMargin    = 1;
							const boxTextY2    = 40;

							var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
							var canvasWidth  = A_iBoxWidth + 2 * boxMargin;
							var boxHeight    = (A_strText2 == '') ? boxHeightStd : 2 * boxHeightStd;
							var canvasHeight = boxHeight + 2 * boxMargin;
							var boxTextY1    = (A_strText2 == '') ? boxHeight / 2 + 3 : boxHeight / 2 - 6;
							var textSize1    = (A_strText2 == '') ? ((A_iBoxWidth == boxWidthKey) ? '14' : '16') : '24';

							r.push('<canvas id="' + A_strCanvasId + '" width="' + canvasWidth.toString() + '" height="' + canvasHeight.toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.font = "bold ' + textSize1 + 'px Arial";');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');
							r.push(canvasCtxStr + '.strokeRect(' + (boxMargin + 0.5).toString() + ', ' + (boxMargin + 0.5).toString() + ', ' + A_iBoxWidth.toString() + ', ' + boxHeight.toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strBoxColour + '";');
							r.push(canvasCtxStr + '.fillRect(' + (boxMargin + 1.5).toString() + ', ' + (boxMargin + 1.5).toString() + ', ' + (A_iBoxWidth - 2).toString() + ', ' + (boxHeight - 2).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strTextColour + '";');
							r.push(canvasCtxStr + '.fillText("' + A_strText1 + '", ' + (A_iBoxWidth / 2 + boxMargin).toString() + ', ' + boxTextY1.toString() + ');');

							if (A_strText2 != '')
							{
								r.push(canvasCtxStr + '.font = "bold 12px Arial";');
								r.push(canvasCtxStr + '.fillText("' + A_strText2 + '", ' + (A_iBoxWidth / 2 + boxMargin).toString() + ', ' + boxTextY2.toString() + ');');
							}

							r.push('</script>');
						}

						///////////////////
						// Main Game Key //
						///////////////////

						var symbSpecial = '';
						var isNumMatch  = false;
						var isBonus     = false;

						r.push('<div style="float:left">');
						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td colspan="2" style="padding-bottom:10px">' + getTranslationByName("titleColoursKey", translations) + '</td>');
						r.push('</tr>');
						r.push('<tr class="tablehead">');
						r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
						r.push('<td style="padding-left:10px">' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('</tr>');

						for (var specialIndex = 0; specialIndex < keySymbs.length; specialIndex++)
						{
							symbSpecial   = keySymbs[specialIndex];
							canvasIdStr   = 'cvsKeySymb' + symbSpecial;
							elementStr    = 'eleKeySymb' + symbSpecial;
							boxColourStr  = specialBoxColours[specialIndex];
							textColourStr = specialTextColours[specialIndex];
							isNumMatch    = (symbSpecial == 'NM');
							textStr1      = (isNumMatch) ? '#' : symbSpecial;
							symbDesc      = getTranslationByName("key" + symbSpecial, translations);

							r.push('<tr class="tablebody">');
							r.push('<td align="center">');

							showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, textColourStr, textStr1, '');

							r.push('</td>');
							r.push('<td style="padding-left:10px">' + symbDesc + '</td>');
							r.push('</tr>');
						}

						r.push('</table>');
						r.push('</div>');

						///////////
						// Grids //
						///////////

						const mgMegaMultis = [0,10,2,3,1,4,2,5,1,4,3,2,1];
						const bgMegaMultis = [0,50,1,10,2,3,1,20,3,5,1,4,2];

						var isMainGrid    = false;
						var gridFirstWin  = true;
						var gridMegaMulti = 0;
						var gridPrize     = 0;
						var gridRowMulti  = 0;
						var gridRowStr    = '';
						var gridStr       = '';
						var gridSubTotal  = 0;
						var gridWin       = 0;
						var matchPrize    = 0;
						var matchWin      = 0;

						r.push('<div style="clear:both">');

						for (var gridIndex = 0; gridIndex < arrGrids.length; gridIndex++)
						{
							isMainGrid = (gridIndex == 0);

							gridStr = (isMainGrid) ? getTranslationByName("mainGrid", translations).toUpperCase() : (getTranslationByName("bonusGrid", translations).toUpperCase() + ' ' + gridIndex.toString());

							r.push('<p><br>' + gridStr + '</p>');

							//////////////
							// Win Nums //
							//////////////

							r.push('<p>' + getTranslationByName("winNums", translations) + '</p>');

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
							r.push('<tr class="tablebody">');

							for (var winNumIndex = 0; winNumIndex < arrGrids[gridIndex].aoWinNums.length; winNumIndex++)
							{
								canvasIdStr  = 'cvsWinNum' + gridIndex.toString() + '_' + winNumIndex.toString();
								elementStr   = 'eleWinNum' + gridIndex.toString() + '_' + winNumIndex.toString();
								boxColourStr = (arrGrids[gridIndex].aoWinNums[winNumIndex].bMatched) ? specialBoxColours[keySymbs.indexOf('NM')] : colourWhite;
								textStr1     = arrGrids[gridIndex].aoWinNums[winNumIndex].iValue.toString();

								r.push('<td align="center" style="padding-right:20px">');

								showBox(canvasIdStr, elementStr, boxWidthNum, boxColourStr, colourBlack, textStr1, '');

								r.push('</td>');
							}

							r.push('</tr>');
							r.push('</table>');

							///////////////
							// Your Nums //
							///////////////

							r.push('<p>' + getTranslationByName("yourNums", translations) + '</p>');

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

							for (var yourNumRowIndex = 0; yourNumRowIndex < arrGrids[gridIndex].aoYourNumRows.length; yourNumRowIndex++)
							{
								r.push('<tr class="tablebody">');
								r.push('<td align="center" style="padding-right:10px">');
								r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
								r.push('<tr class="tablebody">');

								for (var yourNumIndex = 0; yourNumIndex < arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].aoYourNums.length; yourNumIndex++)
								{							
									canvasIdStr   = 'cvsGridYourNum' + gridIndex.toString() + '_' + yourNumRowIndex.toString() + '_' + yourNumIndex.toString();
									elementStr    = 'eleGridYourNum' + gridIndex.toString() + '_' + yourNumRowIndex.toString() + '_' + yourNumIndex.toString();
									isNumMatch    = arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].aoYourNums[yourNumIndex].bMatched;
									isBonus       = arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].aoYourNums[yourNumIndex].bBonusSymb;
									symbSpecial   = (isNumMatch) ? 'NM' : ((isBonus) ? 'B' : '');
									boxColourStr  = (isNumMatch || isBonus) ? specialBoxColours[keySymbs.indexOf(symbSpecial)] : colourWhite;
									textColourStr = (isBonus) ? colourYellow : colourBlack;
									textStr1      = (isBonus) ? symbSpecial : arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].aoYourNums[yourNumIndex].iValue.toString();
									textStr2      = (isBonus) ? ' ' : convertedPrizeValues[getPrizeNameIndex(prizeNames, arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].aoYourNums[yourNumIndex].sPrize)];

									r.push('<td align="center">');

									showBox(canvasIdStr, elementStr, boxWidthPrize, boxColourStr, textColourStr, textStr1, textStr2);

									r.push('</td>');									
								}

								r.push('</tr>');
								r.push('</table>');
								r.push('</td>');

								canvasIdStr  = 'cvsRowMulti' + gridIndex.toString() + '_' + yourNumRowIndex.toString();
								elementStr   = 'eleRowMulti' + gridIndex.toString() + '_' + yourNumRowIndex.toString();
								boxColourStr = (arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].bYourNumRowWin) ? colourLime : colourWhite;
								textStr1     = 'x' + arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].iRowMulti.toString();

								r.push('<td align="center">');

								showBox(canvasIdStr, elementStr, boxWidthNum, boxColourStr, colourBlack, textStr1, '');

								r.push('</td>');
								r.push('</tr>');
							}

							r.push('</table>');

							////////////////
							// Mega Multi //
							////////////////

							r.push('<p>' + getTranslationByName("megaMulti", translations) + '</p>');

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
							r.push('<tr class="tablebody">');

							for (var megaMultiPos = 0; megaMultiPos < 12; megaMultiPos++)
							{
								canvasIdStr  = 'cvsMegaMulti' + gridIndex.toString() + '_' + megaMultiPos.toString();
								elementStr   = 'eleMegaMulti' + gridIndex.toString() + '_' + megaMultiPos.toString();
								boxColourStr = (arrGrids[gridIndex].iMegaMulti == megaMultiPos+1) ? colourLime : colourWhite;
								textStr1     = 'x' + ((isMainGrid) ? mgMegaMultis[megaMultiPos+1].toString() : bgMegaMultis[megaMultiPos+1].toString());

								r.push('<td align="center" style="padding-right:20px">');

								showBox(canvasIdStr, elementStr, boxWidthNum, boxColourStr, colourBlack, textStr1, '');

								r.push('</td>');
							}

							r.push('</tr>');
							r.push('</table>');						

							///////////////
							// Grid Wins //
							///////////////

							if (hasWins || bonusSymbQty > 0)
							{
								if (arrGrids[gridIndex].iMegaMulti != 0)
								{
									r.push('<p>' + getTranslationByName("mgWins", translations) + '</p>');

									r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

									gridStr      = (isMainGrid) ? getTranslationByName("mainGrid", translations) : (getTranslationByName("bonusGrid", translations) + ' ' + gridIndex.toString());
									gridSubTotal = 0;
									gridFirstWin = true;

									for (var yourNumRowIndex = 0; yourNumRowIndex < arrGrids[gridIndex].aoYourNumRows.length; yourNumRowIndex++)
									{
										if (arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].bYourNumRowWin)
										{
											for (var yourNumIndex = 0; yourNumIndex < arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].aoYourNums.length; yourNumIndex++)
											{
												if (arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].aoYourNums[yourNumIndex].bMatched)
												{
													canvasIdStr  = 'cvsGridWinNum' + gridIndex.toString() + '_' + yourNumRowIndex.toString() + '_' + yourNumIndex.toString();
													elementStr   = 'eleGridWinNum' + gridIndex.toString() + '_' + yourNumRowIndex.toString() + '_' + yourNumIndex.toString();
													boxColourStr = specialBoxColours[keySymbs.indexOf('NM')];
													textStr1     = arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].aoYourNums[yourNumIndex].iValue.toString();
													winPrize     = convertedPrizeValues[getPrizeNameIndex(prizeNames, arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].aoYourNums[yourNumIndex].sPrize)];
													gridRowStr   = (gridFirstWin) ? gridStr : '';

													r.push('<tr class="tablebody">');
													r.push('<td>' + gridRowStr+ '</td>');
													r.push('<td>' + getTranslationByName("winMatches", translations) + '</td>');
													r.push('<td align="center">');

													showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, colourBlack, textStr1, '');

													r.push('</td>');
													r.push('<td>' + getTranslationByName("winToWin", translations) + ' ' + winPrize + '</td>');

													canvasIdStr   = 'cvsGridWinMulti' + gridIndex.toString() + '_' + yourNumRowIndex.toString() + '_' + yourNumIndex.toString();
													elementStr    = 'eleGridWinMulti' + gridIndex.toString() + '_' + yourNumRowIndex.toString() + '_' + yourNumIndex.toString();
													gridRowMulti  = arrGrids[gridIndex].aoYourNumRows[yourNumRowIndex].iRowMulti;
													matchPrize    = getPrizeInCents(winPrize) * gridRowMulti;
													matchWin      = getCentsInCurr(matchPrize);
													gridSubTotal += matchPrize;
													textStr1      = 'x' + gridRowMulti.toString();

													r.push('<td align="center">');

													showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, colourBlack, textStr1, '');

													r.push('</td>');
													r.push('<td>= ' + matchWin + '</td>');
													r.push('</tr>');

													gridFirstWin = false;
												}
											}
										}
									}

									r.push('</table>');

									if (gridSubTotal != 0)
									{
										canvasIdStr   = 'cvsGridMulti' + gridIndex.toString();
										elementStr    = 'eleGridMulti' + gridIndex.toString();
										gridMegaMulti = (isMainGrid) ? mgMegaMultis[arrGrids[gridIndex].iMegaMulti] : bgMegaMultis[arrGrids[gridIndex].iMegaMulti];
										gridPrize     = gridSubTotal * gridMegaMulti;
										gridWin       = getCentsInCurr(gridPrize);
										textStr1      = 'x' + gridMegaMulti.toString();

										r.push('<br><table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
										r.push('<tr class="tablebody">');
										r.push('<td>' + gridStr + ' ' + getTranslationByName("gridTotalWin", translations) + ' = ' + getCentsInCurr(gridSubTotal) + '</td>');
										r.push('<td align="center">');

										showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, colourBlack, textStr1, '');

										r.push('</td>');
										r.push('<td>= ' + gridWin + '</td>');
										r.push('</tr>');
										r.push('</table>');
									}
								}

								if (isMainGrid && bonusSymbQty > 0)
								{
									canvasIdStr   = 'cvsMGBonus';
									elementStr    = 'eleMGBonus';
									symbSpecial   = 'B';
									boxColourStr  = specialBoxColours[keySymbs.indexOf(symbSpecial)];
									textColourStr = specialTextColours[keySymbs.indexOf(symbSpecial)];
									textStr1      = symbSpecial;

									r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
									r.push('<tr class="tablebody">');
									r.push('<td align="center">');

									showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, textColourStr, textStr1, '');

									r.push('</td>');
									r.push('<td> : ' + getTranslationByName("winCollected", translations) + ' ' + bonusSymbQty.toString() + ' / ' + mgBonusQty.toString() + '</td>');

									if (bonusSymbQty == mgBonusQty)
									{
										r.push('<td> : ' + getTranslationByName("winTriggers", translations) + ' ' + getTranslationByName("bonusGame", translations) + '</td>');
									}

									r.push('</tr>');
									r.push('</table>');
								}
							}
						}

						r.push('</div>');

						r.push('<p>&nbsp;</p>');

						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						// DEBUG OUTPUT TABLE
						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						if (debugFlag)
						{
							//////////////////////////////////////
							// DEBUG TABLE
							//////////////////////////////////////
							r.push('<table border="0" cellpadding="2" cellspacing="1" width="100%" class="gameDetailsTable" style="table-layout:fixed">');
							for (var idx = 0; idx < debugFeed.length; idx++)
 							{
								if (debugFeed[idx] == "")
									continue;
								r.push('<tr>');
 								r.push('<td class="tablebody">');
								r.push(debugFeed[idx]);
 								r.push('</td>');
	 							r.push('</tr>');
							}
							r.push('</table>');
						}

						return r.join('');
					}

					// Input: A list of Price Points and the available Prize Structures for the game as well as the wagered price point
					// Output: A string of the specific prize structure for the wagered price point
					function retrievePrizeTable(pricePoints, prizeStructures, wageredPricePoint)
					{
						var pricePointList = pricePoints.split(",");
						var prizeStructStrings = prizeStructures.split("|");
						
						for (var i = 0; i < pricePoints.length; ++i)
						{
							if (wageredPricePoint == pricePointList[i])
							{
								return prizeStructStrings[i];
							}
						}
						
						return "";
					}

					// Input: Json document string containing 'scenario' at root level.
					// Output: Scenario value.
					function getScenario(jsonContext)
					{
						// Parse json and retrieve scenario string.
						var jsObj = JSON.parse(jsonContext);
						var scenario = jsObj.scenario;

						// Trim null from scenario string.
						scenario = scenario.replace(/\0/g, '');

						return scenario;
					}
					
					// Input: Json document string containing 'amount' at root level.
					// Output: Price Point value.
					function getPricePoint(jsonContext)
					{
						// Parse json and retrieve price point amount
						var jsObj = JSON.parse(jsonContext);
						var pricePoint = jsObj.amount;

						return pricePoint;
					}

					// Input: "A,B,C,D,..." and "A"
					// Output: index number
					function getPrizeNameIndex(prizeNames, currPrize)
					{
						for(var i = 0; i < prizeNames.length; i++)
						{
							if (prizeNames[i] == currPrize)
							{
								return i;
							}
						}
					}

					////////////////////////////////////////////////////////////////////////////////////////
					function registerDebugText(debugText)
					{
						debugFeed.push(debugText);
					}
					/////////////////////////////////////////////////////////////////////////////////////////

					function getTranslationByName(keyName, translationNodeSet)
					{
						var index = 1;
						while(index < translationNodeSet.item(0).getChildNodes().getLength())
						{
							var childNode = translationNodeSet.item(0).getChildNodes().item(index);
							
							if (childNode.name == "phrase" && childNode.getAttribute("key") == keyName)
							{
								//registerDebugText("Child Node: " + childNode.name);
								return childNode.getAttribute("value");
							}
							
							index += 1;
						}
					}

					// Grab Wager Type
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function getType(jsonContext, translations)
					{
						// Parse json and retrieve wagerType string.
						var jsObj = JSON.parse(jsonContext);
						var wagerType = jsObj.wagerType;

						return getTranslationByName(wagerType, translations);
					}
					]]>
				</lxslt:script>
			</lxslt:component>

			<x:template match="root" mode="last">
				<table border="0" cellpadding="1" cellspacing="1" width="100%" class="gameDetailsTable">
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWager']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/WagerOutcome[@name='Game.Total']/@amount" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWins']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/PrizeOutcome[@name='Game.Total']/@totalPay" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
				</table>
			</x:template>

			<!-- TEMPLATE Match: digested/game -->
			<x:template match="//Outcome">
				<x:if test="OutcomeDetail/Stage = 'Scenario'">
					<x:call-template name="Scenario.Detail" />
				</x:if>
			</x:template>

			<!-- TEMPLATE Name: Scenario.Detail (base game) -->
			<x:template name="Scenario.Detail">
				<x:variable name="odeResponseJson" select="string(//ResultData/JSONOutcome[@name='ODEResponse']/text())" />
				<x:variable name="translations" select="lxslt:nodeset(//translation)" />
				<x:variable name="wageredPricePoint" select="string(//ResultData/WagerOutcome[@name='Game.Total']/@amount)" />
				<x:variable name="prizeTable" select="lxslt:nodeset(//lottery)" />

				<table border="0" cellpadding="0" cellspacing="0" width="100%" class="gameDetailsTable">
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='wagerType']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="my-ext:getType($odeResponseJson, $translations)" disable-output-escaping="yes" />
						</td>
					</tr>
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='transactionId']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="OutcomeDetail/RngTxnId" />
						</td>
					</tr>
				</table>
				<br />			
				
				<x:variable name="convertedPrizeValues">
					<x:apply-templates select="//lottery/prizetable/prize" mode="PrizeValue"/>
				</x:variable>

				<x:variable name="prizeNames">
					<x:apply-templates select="//lottery/prizetable/description" mode="PrizeDescriptions"/>
				</x:variable>


				<x:value-of select="my-ext:formatJson($odeResponseJson, $translations, $prizeTable, string($convertedPrizeValues), string($prizeNames))" disable-output-escaping="yes" />
			</x:template>

			<x:template match="prize" mode="PrizeValue">
					<x:text>|</x:text>
					<x:call-template name="Utils.ApplyConversionByLocale">
						<x:with-param name="multi" select="/output/denom/percredit" />
					<x:with-param name="value" select="text()" />
						<x:with-param name="code" select="/output/denom/currencycode" />
						<x:with-param name="locale" select="//translation/@language" />
					</x:call-template>
			</x:template>
			<x:template match="description" mode="PrizeDescriptions">
				<x:text>,</x:text>
				<x:value-of select="text()" />
			</x:template>

			<x:template match="text()" />
		</x:stylesheet>
	</xsl:template>

	<xsl:template name="TemplatesForResultXSL">
		<x:template match="@aClickCount">
			<clickcount>
				<x:value-of select="." />
			</clickcount>
		</x:template>
		<x:template match="*|@*|text()">
			<x:apply-templates />
		</x:template>
	</xsl:template>
</xsl:stylesheet>
