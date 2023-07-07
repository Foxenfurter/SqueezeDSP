
/*---------------------------------------------------
SqueezeDSP Display logic
Version 00.04 - localdisplayeq was not displaying the bands after reloading a preset, added lines to do this.
Version 00.05 - added in setting of bands to localdisplayeq as this was not working on docker
-----------------------------------------------------*/

function LocalBuildLists(data)
{
		LocalBuildList ('FIRWavFile',data);
		//LocalBuildList ('MatrixFile',data);
		LocalBuildList ('Preset',data);
}


function LocalBuildList (listType, data)
{
		// Get the dropdown Object e.g. sel_MatrixFile
	    var select = document.getElementById("sel_" + listType);
		// Reset the dropdown list so that only the first element is displayed.
		select.options.length = 1;	
		//loop through the data elements for the list type e.g. MatrixFile_loop
		var loop = data.result[ listType + "_loop" ];
		if( typeof loop=="object" )
		{
			
			for( var j=0; j<loop.length; j++ )
			{
				var opt = loop[j][0];
				var el = document.createElement("option");
				el.textContent = opt;
				el.value = opt;
				el.textContent = opt.replace(".wav", "", "i");
				select.appendChild(el);
						
			}
		}
		//return (listType);
}

function LocalbuildEQ(data, labeltype, bands)
{
	try{
			// we are going to build a set of slider controls from the data passed in
			// data = EQ_loop
			var myHTML = "";

			
			//prefer the following as it is clearer
			for ( let i = 0; i < data.length; i++ )
			{
				
				var fgq = data[i];
				//get an element (key / value pair) where j is the key (frequency)
				for(var j in fgq)
				{
				
					// f=frequency, g=gain, q=q
					var f = parseFloat(j);
					!isNaN(f)
					{
						//gain and q are passed within a single | separated string
						var gq = (fgq[j]);
						var g = parseFloat(gq.split('|')[0]);
						var q = parseFloat(gq.split('|')[1]);
						// calculate the postion of the slider based off it's log value
						var fp = log2LinearMapper(f);
					}
					
					if( !isNaN(f) && !isNaN(g) )
					{
						
					  myHTML = myHTML + '<TABLE class="table-container"  id="control_' +  labeltype + i + '" style="background: #fff;"   > ';
					  myHTML = myHTML + '<TR><TD class="rowTitle"></TD><TD class="rowBody">'; 
					  myHTML = myHTML + '		<input type ="number" readonly style="border: none;  visibility: hidden; width: 0 px; height: 0 px;"  id="band_' + labeltype + i + '"  value=' + i + ' ></Input> ';
					  myHTML = myHTML + '<h4>Band ' + (i + 1 ) + '</h4></TD><TD class="rowSuffix"></TD></TR> ';
					  
					  myHTML = myHTML + ' <TR><TD class="rowTitle">' + document.getElementById('Freq_Desc').value  + '</TD> ';
					  myHTML = myHTML + '  <TD class="Slide">';
					  myHTML = myHTML + '   <input  class="range" type="range" orient="horizontal"  min="0" max="100" step=".01" value="' + fp +'"  ' ;
					  myHTML = myHTML + 'onpointerdown="showBubble(this)" onpointerup="hideBubble(this)" ondblclick="EQReset.call(this);"  ';
					  myHTML = myHTML + 'onchange="iSlideEQ(\'' + labeltype + i + '\')" id="' + labeltype + i + '.freq" ></Input> ';
					  myHTML = myHTML + '   <output id="' + labeltype + i + '.freqBubble" class="bubble" ></output>   </TD> ';
					  myHTML = myHTML + '  <TD class="rowSuffix"> ';
					  myHTML = myHTML + '   <Input type="number" onChange="valInputEq(this, true);" min="20" max="20000"  class="OutputVal"   id="val_' +  labeltype + i   +  '.freq" value="' + f +'"  ></Input> ';
					  myHTML = myHTML + '  </TD>  </TR> ';
						
						
					  myHTML = myHTML + ' <TR><TD class="rowTitle">' + document.getElementById('Gain_Desc').value  + '</TD> ';  
					  myHTML = myHTML + '  <TD class="Slide"> ';
					  myHTML = myHTML + '   <input  class="range" type="range" orient="horizontal"  min="-25" max="15" step="0.1" value="' + g +'" ' ;
					  myHTML = myHTML + 'onpointerdown="showBubble(this)" onpointerup="hideBubble(this)" ondblclick="EQReset.call(this);"  ' ;
					  myHTML = myHTML + 'onchange="iSlideEQ(\'' + labeltype + i + '\')" id="' + labeltype + i + '.gain" ></Input> ';
					  myHTML = myHTML + '   <output id="' + labeltype + i + '.gainBubble" class="bubble" ></output>   </TD> ';
					  myHTML = myHTML + '  <TD class="rowSuffix"> ';
					  myHTML = myHTML + '   <Input type="number" onChange="valInputEq(this, false);"  min="-25" max="15" step="0.1"  class="OutputVal"   id="val_' +  labeltype + i   +  '.gain" value="' + g +'"></Input> ';
					  myHTML = myHTML + '  </TD>  </TR> ';
						
					  myHTML = myHTML + ' <TR><TD class="rowTitle"><div class="tooltip"  >Q<span class="tooltiptext">' + document.getElementById('Q_Help').value  + '</span></div></TD> ';  
					  myHTML = myHTML + '  <TD class="Slide"> ';
					  myHTML = myHTML + '   <input  class="range" type="range" orient="horizontal" min="0" max="12" step="0.01" value="' + q +'" ' ;
					  myHTML = myHTML + 'onpointerdown="showBubble(this)" onpointerup="hideBubble(this)" ondblclick="EQReset.call(this);"  ' ;
					  myHTML = myHTML + 'onchange="iSlideEQ(\'' + labeltype + i + '\')" id="' + labeltype + i + '.q" ></Input> ';
					  myHTML = myHTML + '   <output id="' + labeltype + i + '.qBubble" class="bubble" ></output>   </TD> ';
					  myHTML = myHTML + '  <TD class="rowSuffix"> ';
					  myHTML = myHTML + '   <Input type="number" onChange="valInputEq(this, false);"  min="0" max="12" step="0.01" class="OutputVal"   id="val_' +  labeltype + i   +  '.q" value="' + q +'"></Input> ';
					  myHTML = myHTML + '  </TD>  </TR>'; 

					  myHTML = myHTML + '</TABLE>';
									

					}
				}
				
			}
			
	}
	catch
	{
		DisplayAlert("LocalbuildEQ", "Error building EQ profile",3000);
		
	}
	return myHTML;
}	


function replaceNull(ValueToCheck, DefaultValue)
{	
	if ( !ValueToCheck )
	{
		
		return DefaultValue;
	}
	else
	{
		return ValueToCheck;
	}
}


function LocalSetupRadio(myRadio, newValue )
{
	
	var radioObj = document.getElementsByName(myRadio);
	//if(!radioObj)
	//	return;
	
	var radioLength = radioObj.length;
	//alert ('processing radio ' + myRadio + ' | ' + newValue );
	if(radioLength == undefined) {
		radioObj.checked = (radioObj.value == newValue.toString());
		return radioObj;
	}
	for(var i = 0; i < radioLength; i++) {
		radioObj[i].checked = false;
		//alert('Current: ' + radioObj[i].value + ' New: ' + newValue);
		if(radioObj[i].value == newValue) {
			radioObj[i].checked = true;
			return radioObj[i];
		}
	}
	//shouldn't get here now
	return radioObj ;
}

function LocalUpdateSettings (data)
	{
		// Write Data from REST response to Local cache
		UpdateSqueezeDSPData(data);
		
		//Now We display the data from the cache
		LocalDisplayVals();	
		

		//myRadio = LocalSetupRadio( 'val_Bypass' , SqueezeDSPData.Bypass);
		myRadio = LocalSetupToggle('DSP', SqueezeDSPData.Bypass, true );
		ToggleControl(myRadio, 'DSP_container', true );
		//LocalSetupRadio( 'val_EQBands' , SqueezeDSPData.EQBands);
				
		//myRadio = LocalSetupRadio( 'val_Loudness.enabled' , replaceNull(SqueezeDSPData.Loudness_enabled,0));
		myRadio = LocalSetupToggle('Loudness', replaceNull(SqueezeDSPData.Loudness_enabled,0));
		ToggleControl( myRadio, 'control_Loudness' , false );		
		
		myRadio = LocalSetupToggle( 'Lowshelf' , replaceNull(SqueezeDSPData.Lowshelf_enabled,0));
//		myRadio = LocalSetupRadio( 'val_Lowshelf.enabled' , replaceNull(SqueezeDSPData.Lowshelf_enabled,0));
		ToggleControl(myRadio, 'control_Lowshelf', false );
		
		myRadio = LocalSetupToggle( 'Highshelf' , replaceNull(SqueezeDSPData.Highshelf_enabled,0));
//		myRadio = LocalSetupRadio( 'val_Highshelf.enabled' , replaceNull(SqueezeDSPData.Highshelf_enabled,0));
		ToggleControl(myRadio, 'control_Highshelf' , false );

		myRadio = LocalSetupToggle( 'Highpass' , replaceNull(SqueezeDSPData.Highpass_enabled,0));
//		myRadio = LocalSetupRadio( 'val_Highpass.enabled' , replaceNull(SqueezeDSPData.Highpass_enabled,0));
		ToggleControl(myRadio, 'control_Highpass' , false );

		myRadio = LocalSetupToggle( 'Lowpass' , replaceNull(SqueezeDSPData.Lowpass_enabled,0));
		//myRadio = LocalSetupRadio( 'val_Lowpass.enabled' , replaceNull(SqueezeDSPData.Lowpass_enabled,0));
		ToggleControl(myRadio, 'control_Lowpass' , false );
		
		
		LocalDisplayEQ();	
		
		ListenForSlide();
	}



function LocalClearSettings()
{
		//set everything else off.
		DisableControl('Loudness');
		DisableControl('Lowshelf');
		DisableControl('Highshelf');
		DisableControl('Highpass');
		DisableControl('Lowpass');
		SqueezeDSPSelectValue('Preamp', -2);
		SqueezeDSPSelectValue('Delay.delay', 0);
		SqueezeDSPSelectValue('Balance', 0);
		SqueezeDSPSelectValue('Width', 0);
		// disable any FIR filter
		SqueezeDSPSelectValue('FIRWavFile', '-');
		//SqueezeDSPSelectValue('Preset', '-');
		edt_NewPreset.value = '';
		sel_Preset.value = '-' ;				
		//clear eq Settings - as we will most likely be adding them back in
		ClearEQ();
		
}



function HideAlert()
{
	myMessage.className ="bubble";
	myMessage.innerText = '';
}
function DebugAlert(FieldName, Message)
{
	// todo: add in some amendments so this only fires when debug is set
	
	myMessage.className  = "localAlert";
	myMessage.innerText = Message + ' ' + FieldName + " ...";
	setTimeout(function(){ 	HideAlert(); }, 1000);	
}

function DisplayAlert(FieldName, Message, Duration = 1000)
{

	myMessage.className  = "localAlert";
	myMessage.innerText = Message + ' ' + FieldName + " ...";
	setTimeout(function(){ 	HideAlert(); }, Duration);	
}

 function SetNewPreset(myEl) 
 
{
	var val = myEl.value;
	SqueezeDSPSavePreset(val, Initialise);	
	DisplayAlert ('Preset','Saving')	
		
}

function GetLogSummary()
{
	// Calls function to get summary of log for clipping monitor 
	SqueezeDSPLogSummary(LocalDisplayLogSummary);

}

function LocalDisplayLogSummary(logData)
{
	//Display the log summary
	var myHTML = '';
	var peakStyle = 'peak peak-unknown';
	var tracklimit = 10;
	//myHTML = JSON.stringify(logData);
	//myHTML = logData.result['trackcount'];
    /* only display 5 results latest is leftmost - set peak level color based off value		*/ 
	try
    {
      
        for (var i = 1; i <= tracklimit; i++)
        {
		  var peakdBfs = logData.result['peakdBfs_' + i];
		  switch (true)
		  {
			case (peakdBfs < -5):
				peakStyle = 'peak peak-toolow';
				break;
			case (peakdBfs < -1):
				peakStyle = 'peak peak-ok';
				break;
			case (peakdBfs <= 0.1):
				peakStyle = 'peak peak-high';
				break;
			case (peakdBfs > 0.1):
				peakStyle = 'peak peak-clipping';
				break;
			 default:
				peakStyle = 'peak peak-unknown';
				break;
		   }
		   myHTML = myHTML + "<div class='tooltip'  >";	
		   myHTML = myHTML + "<div class='" + peakStyle + "'> </div> "; 

			myHTML = myHTML + " <div class='tooltiptext'><TABLE >";
		   myHTML = myHTML + "		<TR><TD></TD><TD class='text-right'>Playerid:  </TD><TD class='text-left'>"  + logData.result['playerid_' + i] + "</TD></TR>";
		   myHTML = myHTML + "		<TR><TD></TD><TD class='text-right'>Start Date: </TD><TD class='text-left'>" + logData.result['date_' + i] + "</TD></TR>";
		   myHTML = myHTML + "		<TR><TD></TD><TD class='text-right'>Start Time: </TD><TD class='text-left'>"  + logData.result['time_' + i] + "</TD></TR>";
		   myHTML = myHTML + "		<TR><TD></TD><TD class='text-right'>Preamp Gain: </TD><TD class='text-left'>"  + logData.result['preamp_' + i] + "</TD></TR>";
		   myHTML = myHTML + "		<TR><TD></TD><TD class='text-right'>Sample Rate:  </TD><TD class='text-left'>"  + logData.result['outputrate_' + i]+ "</TD></TR>";
		   myHTML = myHTML + "		<TR><TD></TD><TD class='text-right'>Peak Level:  </TD><TD class='text-left'>"  + logData.result['peakdBfs_' + i] + "</TD></TR>";
		   myHTML = myHTML + "	</TABLE></div>";
		   myHTML = myHTML + "	</span>";                
		   myHTML = myHTML + "</div>";                
                
        }
        
    }
    catch
    {
        DisplayAlert("LocalDisplayLogSummary", "Error building log summary", 3000);
        
    }
    document.getElementById('logSummary').innerHTML = myHTML;

}


function LocalDisplayEQ()
{
	
	
	var myEQ=SqueezeDSPData.EQ_loop;
	var myBands=SqueezeDSPData.EQBands;
	if (myBands> 0 )
	{
		var mytempHTML = LocalbuildEQ(myEQ, 'Slide', myBands);
		document.getElementById('control_EQ').innerHTML = mytempHTML;
	}
	// Added lines below because EQ not loaded on load of a preset.
	var myElement = document.getElementById('val_EQBands');
	ToggleEQ(myElement, 'control_EQ' );		
}

function LocalDisplayVals()
{

		DisplayVal('Delay.delay', SqueezeDSPData.Delay_delay);
		DisplayVal('Width', SqueezeDSPData.Width);
		
		DisplayVal('Balance', SqueezeDSPData.Balance);
		DisplayVal('Preamp', SqueezeDSPData.Preamp);
		
		// defaults selected such that the gain needs to be applied
		// defaults are now being applied in the server end so this is not really necessary
		DisplayVal('Loudness.listening_level',replaceNull( SqueezeDSPData.Loudness_listening_level,85));
		DisplayVal('Lowshelf.gain', replaceNull( SqueezeDSPData.Lowshelf_gain,0));
		DisplayVal('Lowshelf.slope', replaceNull(SqueezeDSPData.Lowshelf_slope, 12));
		DisplayVal('Lowshelf.freq', replaceNull(SqueezeDSPData.Lowshelf_freq, 300));
		
		// defaults selected such that the gain needs to be applied
		DisplayVal('Highshelf.gain', replaceNull(SqueezeDSPData.Highshelf_gain,0));
		DisplayVal('Highshelf.slope', replaceNull(SqueezeDSPData.Highshelf_slope, 12));
		DisplayVal('Highshelf.freq', replaceNull(SqueezeDSPData.Highshelf_freq, 8000));
					
		DisplayVal('Highpass.q', SqueezeDSPData.Highpass_q);
		DisplayVal('Highpass.freq', SqueezeDSPData.Highpass_freq);
		
		DisplayVal('Lowpass.q', SqueezeDSPData.Lowpass_q);
		DisplayVal('Lowpass.freq', SqueezeDSPData.Lowpass_freq);
				
		document.getElementById('ClientName').value = SqueezeDSPData.ClientName ;
		
		document.getElementById('val_EQBands').value = SqueezeDSPData.EQBands;
		
		// Set the values for dropdowns
		//document.getElementById('sel_MatrixFile').value = SqueezeDSPData.MatrixFile;
		document.getElementById('sel_FIRWavFile').value = SqueezeDSPData.FIRWavFile;
		
		// Sliders for frequencies are mapped to a log scale 
		positionFreqSlider('Highpass.freq',  SqueezeDSPData.Highpass_freq);
		positionFreqSlider('Lowshelf.freq',  SqueezeDSPData.Lowshelf_freq);
		positionFreqSlider('Highshelf.freq',  SqueezeDSPData.Highshelf_freq);
		positionFreqSlider('Lowpass.freq',  SqueezeDSPData.Lowpass_freq);
		

}


function DisplayVal(ElName, MyVal)
{
	try
	{
		document.getElementById(ElName).value = MyVal;
		document.getElementById('val_' + ElName ).value = MyVal;
	}
	catch
	{
		DebugAlert	( ElName, "Function DisplayVal failing for:"  );
	}
}




function iSlide (myObj){
	
	myVal = document.getElementById ('val_' + myObj.id );
	var mySlideName = myObj.id;
	if ( mySlideName.endsWith("freq")  	)
	{
		myVal.value = logScaleMapper(myObj.value); 	
		//myObj.value = myVal.value			
	}
	else
	{
		myVal.value = myObj.value;		
	}	
	
	
	document.getElementById(myObj.id + 'Bubble').style.display = 'none';	
	NewFieldValue(myObj.id, myVal, false);
	
}

function SliderReset (){
	try {
			this.value = 0;
			myVal = document.getElementById ('val_' + this.id );
			myVal.value = this.value;
			NewFieldValue(this.id, myVal, false);
	}
	catch{
		alert('Error on SliderReset');
	}
	
}

function AddEQBand()
{
	/* Add a new band unless max of 31 reached */
	var myObj= document.getElementById('val_EQBands');
	var myObjvalue = Number(myObj.value);

	if ( myObjvalue < 31 )
	{
		myObj.value = myObjvalue + 1;
		NewFieldValue ('EQBands', myObj ,  true);
		ToggleEQ(myObj, 'control_EQ' );
	}
}

function DelEQBand()
{
	/* delete a  band unless min of 0 reached */
	var myObj= document.getElementById('val_EQBands');
	var myObjvalue = parseInt(myObj.value,10);
	
	if ( myObjvalue > 0 )
	{
		myObj.value = myObjvalue - 1;
		NewFieldValue ('EQBands', myObj ,  true);
		ToggleEQ(myObj, 'control_EQ' );
	}
}


function ClearEQ()
{
		myElement = document.getElementById('val_EQBands');
		myElement.value = 0;
		NewFieldValue ('EQBands', myElement ,  true);
		ToggleEQ(myElement, 'control_EQ' );
}



function EQReset()
{
	try {
	
	myObj = this.id;
	//Set gain to zero for EQ Slider. Other values not affected
	this.value = 0; 
	document.getElementById ('val_' + myObj ).value = this.value;
	
	var myBand = document.getElementById ('band_' + myObj ).value;
	var myGain = document.getElementById ('val_' + myObj ).value;
	var myFreq = document.getElementById ('freq_' + myObj ).value; 
	
	var myQ = document.getElementById ('q_' + myObj ).value;
	//document.getElementById(this + 'Bubble').style.display = 'none';
			
	SqueezeDSPSaveEQBand(myBand, myFreq, myGain, myQ)	;	
	DisplayAlert (' EQ: ' + myFreq + ' Hz ','Setting' );	
	}
	catch{
		alert('Error on EQReset');
	}
	
}


function iSlideEQ (myObj){
	//myObj is name of an object, namely the EQ Slider
	// use log scale for frequency
	document.getElementById('val_' + myObj + '.freq' ).value = logScaleMapper(document.getElementById( myObj + '.freq' ).value);
	document.getElementById('val_' + myObj + '.q' ).value = document.getElementById( myObj + '.q' ).value;
	document.getElementById('val_' + myObj + '.gain' ).value = document.getElementById( myObj + '.gain' ).value;
	//could add in some validation here to stop bad values from being saved.
	var myBand = document.getElementById ('band_' + myObj ).value;

	var myGain = document.getElementById ('val_' + myObj  + '.gain' ).value;
	var myFreq = document.getElementById ('val_' + myObj + '.freq' ).value; 
	var myQ = document.getElementById ('val_' + myObj  + '.q').value;
			
	SqueezeDSPSaveEQBand(myBand, myFreq, myGain, myQ)	;	
	DisplayAlert (' EQ: ' + myFreq + ' Hz ','Setting' );
	
	document.getElementById(myObj + '.freqBubble').style.display = 'none';
	document.getElementById(myObj + '.qBubble').style.display = 'none';
	document.getElementById(myObj + '.gainBubble').style.display = 'none';
}

function valInputEq (myElement , isFreq){

	//use this when setting EQ value via the input box rather than slider
      var val = parseFloat(myElement.value),
            min = parseFloat(myElement.min),
            max = parseFloat(myElement.max),
            step = parseFloat(myElement.step);

      if (val > max) {
        myElement.value = max;
      }
      if (val < min) {
        myElement.value = min;
      }
		  // convention is that outputval = sliderid prefixed by val_, so strip out val_ and we have slider id.
	  var myElementId = myElement.id;
	  //get rid of the prefix as my Slider is the current slider
	  var mySlider = myElementId.replace('val_','');
	 
	  if ( isFreq ){
		document.getElementById(mySlider).value = log2LinearMapper(myElement.value);
		}
	  else
	  {
		document.getElementById(mySlider).value = myElement.value;
	  }
	  //myObj is current band name
	  var myObj = mySlider.replace('.gain','');
	  myObj = myObj.replace('.freq','');
	  myObj = myObj.replace('.q','');
	 
	//myObj is name of an object, namely the EQ Slider
	// use log scale for frequency
	//document.getElementById('val_' + myObj + '.freq' ).value = logScaleMapper(document.getElementById( myObj + '.freq' ).value);
	//document.getElementById('val_' + myObj + '.q' ).value = document.getElementById( myObj + '.q' ).value;
	//document.getElementById('val_' + myObj + '.gain' ).value = document.getElementById( myObj + '.gain' ).value;
	//could add in some validation here to stop bad values from being saved.
	var myBand = document.getElementById ('band_' + myObj ).value;

	var myGain = document.getElementById ('val_' + myObj  + '.gain' ).value;
	var myFreq = document.getElementById ('val_' + myObj + '.freq' ).value; 
	var myQ = document.getElementById ('val_' + myObj  + '.q').value;
		
	SqueezeDSPSaveEQBand(myBand, myFreq, myGain, myQ)	;	
	DisplayAlert (' EQ: ' + myFreq + ' Hz ','Setting' );

}



function valInputDecimal(myElement)
{	
	//use this when setting any non-frequency value via the input box rather than slider
      var val = parseFloat(myElement.value),
            min = parseFloat(myElement.min),
            max = parseFloat(myElement.max),
            step = parseFloat(myElement.step);

      if (val > max) {
        myElement.value = max;
      }
      if (val < min) {
        myElement.value = min;
      }
	  // convention is that outputval = sliderid prefixed by val_, so strip out val_ and we have slider id.
	  var myElementId = myElement.id;
	  var mySliderId = myElementId.replace('val_','');

	  document.getElementById(mySliderId).value=myElement.value;
	 
	  NewFieldValue(mySliderId, myElement, false);	
	  
}


function valInputLog(myElement)
{
	//use this when setting frequency via the input box rather than slider
      var val = parseFloat(myElement.value),
            min = parseFloat(myElement.min),
            max = parseFloat(myElement.max),
            step = parseFloat(myElement.step);

      if (val > max) {
        myElement.value = max;
      }
      if (val < min) {
        myElement.value = min;
      }
	  // convention is that outputval = sliderid prefixed by val_, so strip out val_ and we have slider id.
	  var myElementId = myElement.id;
	  var mySliderId = myElementId.replace('val_','');

	  document.getElementById(mySliderId).value=log2LinearMapper(myElement.value);
	 
	  NewFieldValue(mySliderId, myElement, false);	
	  
}



function LocalSetupToggle(myControl, newValue, InvertToggle = false  )
{
	myCheck = document.getElementById(myControl);
	myCheck.value = newValue;
	//alert(myCheck.value);
	if ( myCheck.value == 1 ) 
	{
		if (!InvertToggle )
		{
			myCheck.checked = true;
		}
		else 
		{
			myCheck.checked = false;
		}
	}
	if ( myCheck.value == 0)
	{
		if(InvertToggle )
		{
			myCheck.checked = true;
		}
		else 
		{
			myCheck.checked = false;
		}
	}
	//alert(myCheck.checked);
	return myCheck ;
}



function ToggleEQ(myElement, myControltoToggle)
{
// EQ doesn't need any style setting, clearer to split the function
	var myValue = myElement.value;
	if ( myValue == 0 )
	{
			document.getElementById(myControltoToggle).style.display = 'none';			
	}
	else
	{
			document.getElementById(myControltoToggle).style.display = '';
	}

}

function ToggleControl(myElement, myControltoToggle, InvertToggle = false )
{
//toggle the relevant control on or off depending on field value 

	var myValue = myElement.value;
/*	if ( myElement.id == 'DSP'){
		alert (myElement.id + ':' + myValue + ':' + myControltoToggle + ':' + InvertToggle );
	}
*/	
	if (InvertToggle)
	{
		if ( myValue == 1 )
			{
				document.getElementById(myControltoToggle).style.display = 'none';
				//myElement.parentElement.className = 'switch switch-off';
			}
		else
			{
				document.getElementById(myControltoToggle).style.display = '';
				//myElement.parentElement.className = 'switch switch-on';
			}

	}
	else
	{
		if ( myValue == 0 )
		{
			document.getElementById(myControltoToggle).style.display = 'none';
			//myElement.parentElement.className = 'switch switch-off';
		}
		else
		{
			document.getElementById(myControltoToggle).style.display = '';
			//myElement.parentElement.className = 'switch switch-on';
		}

	}
}

function SwitchCheckbox(myElement, InvertToggle = false ){

  
    if (myElement.checked )
     { if (!InvertToggle ) 
         {
         myElement.value=1;
         }
         else {
         myElement.value= 0;
         }
     }
     
     if (!myElement.checked)
     {
         if( InvertToggle )
         {
            myElement.value=1;
         }
         else {
             myElement.value= 0;
         }
        
     }
    //alert('SwitchCheckbox' + myElement.value);
    
 }
 


function roundToNearest(numIn, roundto = 5) {
  // Allows the round target to be defined
  return Math.round(numIn / roundto) * roundto;
}


// use this for non linear sliders - frequencey
function logScaleMapper(value) {
  const minLinear = 0;
  const maxLinear = 100;
  const minLog = Math.log10(20);
  const maxLog = Math.log10(20000);
  var retval;

  // Calculate the logarithmic value

  const logValue = ( maxLog - minLog ) / (maxLinear - minLinear) * (value - minLinear) + minLog;
  // Convert the logarithmic value back to a linear scale and round
  retval = Math.round( Math.pow(10, logValue) );
  
  // now we want nice numbers e.g. 11000 not 11021
  if (retval > 12000 )
	//increment by 1000 
	{retval = roundToNearest(retval, 1000); }
  else if ( retval >= 5000 && retval < 12000 )
	{retval = roundToNearest(retval, 100); }
  else if ( retval >= 1000 && retval < 5000 )
	{retval = roundToNearest(retval, 10); }
  else if ( retval > 30 && retval < 1000 )
	//increment by 5 
	{ retval = roundToNearest(retval, 5); }
  // less than 30 we don't apply rounding	
  return retval;
}

function log2LinearMapper(value)
{
  const minLog = Math.log10(20);
  const maxLog = Math.log10(20000);

  // Get the minimum and maximum values of the slider control
  const minLinear = 0;
  const maxLinear = 100;
  // Calculate the logarithmic value of the input number
  
  const logValue = ( Math.log10(value) - minLog ) / ( maxLog - minLog );
  
  // Calculate the slider position based on the logarithmic value
  const sliderPosition = minLinear + ( logValue * (maxLinear - minLinear)) ;
  
  return sliderPosition;
}


function positionFreqSlider(elementname,value) {
  // function maps the logarithmic values back to the slider scale.
  var myObj = document.getElementById(elementname);


  myObj.value = log2LinearMapper(value);
 
}

function DisableControl(myControl)
{
		// simplify switching off controls
		myElement =  LocalSetupToggle(myControl, 0);
		
		//LocalSetupRadio( 'val_' + myControl +  '.enabled' ,  0 );
		//myElement= document.getElementById( myControl);
		//NewFieldValue ('Loudness.enabled', this, false);
		NewFieldValue (myControl + '.enabled', myElement ,  false);
		ToggleControl(myElement, 'control_' + myControl );
		
}

function EnableControl(myControl)
{
		// simplify switching off controls
		myElement = LocalSetupToggle(myControl, 1);
		//LocalSetupRadio( 'val_' + myControl +  '.enabled' ,  1 );
		//myElement= document.getElementById( myControl);
		//myElement= document.getElementById( myControl + 'On');
		NewFieldValue (myControl + '.enabled', myElement ,  false);
		//NewFieldValue (myControl + '.enabled', myElement ,  false);
		ToggleControl(myElement, 'control_' + myControl );

}

function NewFieldValue(FieldName, myEl, RefreshAfter)
{
	//var myHost = myEl.parentNode.parentNode;
	
	var val = myEl.value;
	//alert (val);
	if (RefreshAfter == true)
	 {
		SqueezeDSPSelectValue (FieldName, val, LocalUpdateSettings);
	 }
	 else
	 {
		SqueezeDSPSelectValue (FieldName, val);
	 }
	DisplayAlert (FieldName,'Setting');
}

function GetCurrentPlayerSettings()
{
	var myplayerconfigfile = myPlayer.value + '.settings.json' ;
	//now replace the :
	myplayerconfigfile = myplayerconfigfile.replaceAll(":", "_"); 
	SqueezeDSPSelectValue ('Preset', myplayerconfigfile , LocalUpdateSettings);
}


function SetAmb(myEl)
{
	
	//NewFieldValue(FieldName, myEl,  false);
	val = myEl.value;
	// Show angle and directivity if this is Crossed or Crossed+jW
	var ctrl = document.getElementById("control_AmbAngle");
	if(ctrl)
	{
		ctrl.style.display = (val=="Crossed" || val=="Crossed+jW") ? "" : "none";
	}
	ctrl = document.getElementById("control_AmbDirect");
	if(ctrl)
	{
		ctrl.style.display = (val=="Crossed" || val=="Crossed+jW") ? "" : "none";
	}
	ctrl = document.getElementById("control_AmbjW");
	if(ctrl)
	{
		ctrl.style.display = (val=="Crossed+jW") ? "" : "none";
	}
}

function Initialise()
{
	
	//get settings and callback to local update
	DisplayAlert('All Fields', 'Intialise');
	SqueezeDSPGetList(LocalBuildLists);
	SqueezeDSPGetSettings(LocalUpdateSettings);

}

function control_check()
{
		DisplayAlert('connecting to', 'control lib');
		//alert ('control_library version:- ' + ControlLibVersion  ); 
}

//Bubble against sliders
//from Chris Coyier on Mar 26, 2020
//https://css-tricks.com/value-bubbles-for-range-inputs/#update-new-version-with-vanilla-javascript-that-also-works-better

function ListenForSlide()
{
	const allRanges = document.querySelectorAll(".Slide");
	  allRanges.forEach(wrap => {
	  const range = wrap.querySelector(".range");
	  const bubble = wrap.querySelector(".bubble");

	  range.addEventListener("input", () => {
		setBubble(range, bubble);
	  });
	  setBubble(range, bubble);
	});
}


function setBubble(range, bubble) {
  const val = range.value;
  const min = range.min ? range.min : 0;
  const max = range.max ? range.max : 100;


  var mySlideName = range.id;
  if ( mySlideName.endsWith("freq")  	)
  {
  	bubble.innerHTML = logScaleMapper(val); 		
  }
  else
  {
	bubble.innerHTML = val; 		
  }	
  
  // get the width of the range slider and multiply by the value as a fraction of the total range
 
  const newVal = (range.offsetWidth * ((val - min) ) / (max - min)) ;
 
  bubble.style.left = `calc(${newVal}px)`;
}

function showBubble(myObj)
{
		
		var myBubble = document.getElementById(myObj.id + 'Bubble');
		//initialise the bubble position
		setBubble (myObj, myBubble);
		// now make it visible
		myBubble.style.display = 'block';
}

function hideBubble(myObj)
{
	document.getElementById(myObj.id + 'Bubble').style.display = 'none';
}

//End of Bubble

// File Handler

function ProcessREW(EQText) {
  
    LocalClearSettings();
    
    // split records on new line
    EQRecords = EQText.split(/\r?\n/);;
    EQBands = 0;


for (var i = 0; EQRecords.length; i++ )
{
    
    // split on white space
    //see https://stackoverflow.com/questions/26425637/javascript-split-string-with-white-space
    
    // find filters
    if ( EQRecords[i].startsWith('Preamp') )
    {
        var PreampSettings = EQRecords[i].split(/(\s+)/).filter( function(e) { return e.trim().length > 0; } );
        Gain = Math.round (PreampSettings[1]  * 100) / 100 ;
        DisplayVal('Preamp', Gain);
        myElement = document.getElementById ('val_Preamp' );
        NewFieldValue( 'Preamp' , myElement, false);
        //alert ( Gain);
    }
    
    
    if ( EQRecords[i].startsWith('Filter') )
    {

        var EQSettings = EQRecords[i].split(/(\s+)/).filter( function(e) { return e.trim().length > 0; } );
        
        if (EQSettings[2] == 'ON')
            {
            // should have got an EQ setting
                FilterType = EQSettings[3];
                if (FilterType == 'PK')
                {
                    
                    AddEQBand();
                    
                    Freq = Math.round ( EQSettings[5] );
                    Gain = Math.round (EQSettings[8] * 100) / 100 ;
                    Q = Math.round (EQSettings[11] * 100) / 100 ;
                    
                    SqueezeDSPSaveEQBand(EQBands, Freq, Gain, Q);
                    EQBands += 1;
                    //alert ( FilterType.concat( ' ',  EQBands, ' ',  Freq, ' ', Gain , ' ', Q ) );
                }
                if (FilterType == 'LS')
                {
                    EnableControl('Lowshelf');
                    
                    Freq = Math.round( EQSettings[5]);
                    SqueezeDSPSelectValue ('Lowshelf.freq', Freq);
                    
                    Gain = Math.round (EQSettings[8] * 100) / 100 ;
                    SqueezeDSPSelectValue ('Lowshelf.gain', Gain);
                    // NB we want to use Slope
                    Q = Math.round (EQSettings[11] * 100) / 100 ;
                    SqueezeDSPSelectValue ('Lowshelf.slope', Q);
                }
                
                if (FilterType == 'HS')
                {
                    EnableControl('Highshelf');
                    Freq = Math.round( EQSettings[5]);
                    SqueezeDSPSelectValue('Highshelf.freq', Freq);

                    Gain = Math.round (EQSettings[8] * 100) / 100 ;
                    SqueezeDSPSelectValue('Highshelf.gain', Gain);
                    // NB we want to use Slope
                    Q = Math.round (EQSettings[11] * 100) / 100 ;
                    SqueezeDSPSelectValue('Highshelf.slope',Q);						
                }
            }
                    
        
    }
}

}


function ConfirmREW(EQText)
{
	if(!confirm ('Load the Settings:' + '\n' + EQText ) )
	{
		return;
	}
	ProcessREW(EQText);

}



function readFile(file, callback) {
    const reader = new FileReader();
  
    reader.onload = () => {
      callback(reader.result);
    }
  
    reader.readAsText(file);
    outputlist("Last File loaded was: "  + file.name  );
  }


  function dodrop(event)
  {
      var dt = event.dataTransfer;
      var files = dt.files;
      if (files.length > 1)
      {
          outputlist ('Only 1 file at a time Please');
          return;
      }
  
      for (var i = 0; i < files.length; i++) 
      {
          
          
          readFile(files[i], ConfirmREW);
      }
  }
  
  function outputlist(text)
  {
      document.getElementById("LastFile").textContent = text;
      document.getElementById("rewpicker").value = "";
  }
