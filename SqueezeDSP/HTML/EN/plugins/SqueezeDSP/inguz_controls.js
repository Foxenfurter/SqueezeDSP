
/*---------------------------------------------------

Inguz Display logic
-----------------------------------------------------*/
function LocalBuildLists(data)
{
		LocalBuildList ('Filter',data);
		LocalBuildList ('Matrix',data);
		LocalBuildList ('Preset',data);
}


function LocalBuildList (listType, data)
{
		// Get the dropdown Object e.g. sel_Matrix
	    var select = document.getElementById("sel_" + listType);
		// Reset the dropdown list so that only the first element is displayed.
		select.options.length = 1;	
		//loop through the data elements for the list type e.g. Matrix_loop
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



function LocalbuildEQ(data, labeltype)
{
	// we are going to build a set of slider controls from the data passed in
	var myHTML = "";
	var i = 0;
	for(var i in data)
	{
		var lfg = data[i];
		for(var j in lfg)
		{
			// F=frequency, g=gain
			var f = parseFloat(j);
			var g = parseFloat(lfg[j]);
			if( !isNaN(f) && !isNaN(g) )
			{

				
				//style="visibility:hidden"
				myHTML = myHTML + '<TR  id="control_' +  labeltype + i + '" >';
				myHTML = myHTML + '<TD class="rowTitle"><Output style="visibility:hidden; width: 1px;" id="band_' + labeltype + i + '" >' + i  
				myHTML = myHTML + '</Output><Output id="freq_' + labeltype + i + '" >' + f + '</Output>'
				myHTML = myHTML + '&nbsp;Hz</TD>';
				myHTML = myHTML + '<TD class="Slide">';
				myHTML = myHTML + '<input  class="range" type="range" orient="horizontal"  min="-15" max="15" step="0.1" value="' + g +'" ' ;
				myHTML = myHTML + 'onpointerdown="showBubble(this)" onchange="iSlideEQ(this)" id="' + labeltype + i + '" ></Input>';
				myHTML = myHTML + '<output id="' + labeltype + i + 'Bubble" class="bubble" ></output></TD>';
				myHTML = myHTML + '<TD class="rowSuffix"><Output id="val_' + labeltype + i + '">' + g + '</Output>&nbsp;dB</TD>';
				myHTML = myHTML + '</TR>';
				
				i++;
			}
		}
	}
	return (myHTML);
	
}	


function LocalSetupRadio(myRadio, newValue )
{
	
	var radioObj = document.getElementsByName(myRadio);
	//if(!radioObj)
	//	return;
	
	var radioLength = radioObj.length;
	//alert ('processing radio length ' + radioLength);
	if(radioLength == undefined) {
		radioObj.checked = (radioObj.value == newValue.toString());
		return;
	}
	for(var i = 0; i < radioLength; i++) {
		radioObj[i].checked = false;
		//alert('Current: ' + radioObj[i].value + ' New: ' + newValue);
		if(radioObj[i].value == newValue) {
			radioObj[i].checked = true;
		}
	}
	
}



function LocalUpdateSettings (data)
	{
		// Write Data from REST response to Local cache
		UpdateInguzData(data);
		
		//Now We display the data from the cache				
		LocalSetupRadio( 'val_Bands' , InguzData.Bands);	
		LocalDisplayEQ();	
		LocalDisplayVals();
		ListenForSlide();
	}


function HideAlert()
{
	myMessage.className ="bubble";
	myMessage.innerText = '';
}

function DisplayAlert(FieldName, Message)
{

	myMessage.className  = "localAlert";
	myMessage.innerText = Message + ' ' + FieldName + " ...";
	setTimeout(function(){ 	HideAlert(); }, 1000);	
}

 function SetNewPreset(myEl) 
 
{
	var val = myEl.value;
	InguzSavePreset(val, Initialise);
	
	DisplayAlert ('Preset','Saving')	
		
}



function LocalDisplayEQ()
{
	//alert ('LocalDisplayEQ');
	var myEQ=InguzData.EQ_loop;

	document.getElementById('control_EQ').innerHTML = LocalbuildEQ(myEQ, 'Slide');
}

function LocalDisplayVals()
{
		
		
		//alert(document.getElementById('Skew').value +':'+  InguzData.Skew);
		DisplayVal('Skew', InguzData.Skew);
		DisplayVal('Flatness', InguzData.Flatness);
		DisplayVal('Quietness', InguzData.Quietness);
		DisplayVal('Balance', InguzData.Balance);
		DisplayVal('Width', InguzData.Width);
		DisplayVal('AmbRotateX',  InguzData.AmbRotateX); 
		DisplayVal('AmbRotateY', InguzData.AmbRotateY ); 
		DisplayVal('AmbRotateZ',InguzData.AmbRotateZ ); 
		 
		DisplayVal('AmbjW',InguzData.AmbjW ); 
		DisplayVal('AmbAngle',InguzData.AmbAngle); 
		DisplayVal('AmbDirect',InguzData.AmbDirect);
		
		// Set the values for dropdowns
		document.getElementById('sel_Matrix').value = InguzData.Matrix;
		document.getElementById('sel_Filter').value = InguzData.Filter;
		
		//ambi filter is a bit mroe complex
		var myEl = document.getElementById('sel_Amb');
		myEl.value = InguzData.Amb;
		SetAmb( myEl);
					
}


function DisplayVal(ElName, MyVal)
{
		document.getElementById(ElName).value = MyVal;
		document.getElementById('val_' + ElName ).value = MyVal;
}


function iSlide (myObj){
	
	myVal = document.getElementById ('val_' + myObj.id );
	myVal.value = myObj.value;
	document.getElementById(myObj.id + 'Bubble').style.display = 'none';	
	NewFieldValue(myObj.id, myObj, false);
	
}


function iSlideEQ (myObj){
	document.getElementById ('val_' + myObj.id ).value = myObj.value;
	var myGain = document.getElementById ('val_' + myObj.id ).value;
	var myFreq = document.getElementById ('freq_' + myObj.id ).value; 
	var myBand = document.getElementById ('band_' + myObj.id ).value; 
	document.getElementById(myObj.id + 'Bubble').style.display = 'none';
		
	InguzSaveEQBand(myBand, myFreq, myGain)	;	
	DisplayAlert (' EQ: ' + myFreq + ' Hz','Setting');	
}


function NewFieldValue(FieldName, myEl, RefreshAfter)
{
	//var myHost = myEl.parentNode.parentNode;
	
	var val = myEl.value;
	
	if (RefreshAfter == true)
	 {
		InguzSelectValue (FieldName, val, LocalUpdateSettings);
	 }
	 else
	 {
		InguzSelectValue (FieldName, val);
	 }
	DisplayAlert (FieldName,'Setting');
}

function GetCurrentPlayerSettings()
{
	InguzSelectValue ('Preset', myPlayer.value, LocalUpdateSettings);
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
	InguzGetSettings(LocalUpdateSettings);
	InguzGetList(LocalBuildLists);
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

  bubble.innerHTML = val; 		
  
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

//End of Bubble
