// Lets create the  SqueezeDSPData object
function getCurrentPlayer()
{
   return (playerid);
}

SqueezeDSPData = function()

{
    
	this._EQ_loop = {};

	// Dictionary of lists (rc & matrix filters, presets)
	this.Lists = {};
	this.Matrix = "";
	this.Filter = "";
	this.Preset = "";
	this.AmbRotateX = "12";
	this.AmbRotateY = 0;
	this.AmbRotateZ = 0;
	this.Amb = 0;
	this.AmbjW = 0;
	this.AmbAngle = 0;
	this.AmbDirect = 0;
	this.Bands = 2;
	this.Balance = 0 ;
	this.Skew = 0;
	this.Flatness= 10 ;
	this.Quietness = 0;

}

function UpdateSqueezeDSPData(data)
{
		SqueezeDSPData.AmbRotateX = data.result['AmbRotateX'];
		SqueezeDSPData.AmbRotateY =  data.result['AmbRotateY'];
		SqueezeDSPData.AmbRotateZ =   data.result['AmbRotateZ'];
		SqueezeDSPData.Amb =   data.result['Amb'];
		SqueezeDSPData.AmbjW =   data.result['AmbjW'];
		SqueezeDSPData.AmbAngle =   data.result['AmbAngle'];
		SqueezeDSPData.AmbDirect =   data.result['AmbDirect'];
		SqueezeDSPData.Bands =   data.result['Bands'];
		SqueezeDSPData.Balance =   data.result['Balance'];
		SqueezeDSPData.Skew =   data.result['Skew'];
		SqueezeDSPData.Flatness =   data.result['Flatness'];
		SqueezeDSPData.Quietness =   data.result['Quietness'];
		SqueezeDSPData.Width =   data.result['Width'];
		
		SqueezeDSPData.Matrix = data.result['Matrix'];
		SqueezeDSPData.Filter = data.result['Filter'];
		SqueezeDSPData.Preset = data.result['Preset'];
		
		// Copy EQ_loop
		SqueezeDSPData.EQ_loop = data.result.EQ_loop;

}


function SqueezeDSPGetList(callback)
{
	SilverlightPlugInHost.innerText = '';
	new Ajax.Request('/jsonrpc.js', {
		method: 'post',
		asynchronous: true,
		postBody: Object.toJSON({
			id: 1, 
			method: 'slim.request', 
			params: [
				getCurrentPlayer(), 
				[
					'SqueezeDSP.filters'
				]
			]
		}),

		onFailure: function() { alert('Failed'); },

		onSuccess: function(response) {
			// debugger;
		var data = response.responseText.evalJSON(true);

		callback(data);

		}
	});
}

function SqueezeDSPGetSettings(callback)
{
	new Ajax.Request('/jsonrpc.js', {
		method: 'post',
		asynchronous: true,
		//asynchronous: false,
		postBody: Object.toJSON({
			id: 1, 
			method: 'slim.request', 
			params: [
				getCurrentPlayer(), 
				[
					'SqueezeDSP.current'
				]
			]
		}),

		onFailure: function() { alert('Failed'); },

		onSuccess: function(response) {
			// debugger;
		var data = response.responseText.evalJSON();
		callback(data);
		
		}
	});

}

function SqueezeDSPSelectPreset()
{
	// Save this value (async)
	var myProperty='Preset';
	var myVal = 'Joxy.preset.conf';
	new Ajax.Request('/jsonrpc.js', {
		method: 'post',
		asynchronous: true,
		postBody: Object.toJSON({
			id: 1, 
			method: 'slim.request', 
			params: [
				getCurrentPlayer(), 
				[
					'SqueezeDSP.setval',
					'key:'+myProperty,
					'val:'+myVal
				]
				]
			}),
			onFailure: function() { alert('Failed') },
			onSuccess: function(response) { 	// debugger;
			var data = response.responseText.evalJSON();
			SqueezeDSPGetSettings(LocalUpdateSettings);
			}
		});
	}

function SqueezeDSPSelectValue(myProperty, myVal, callback)
{
	// Save this value (async)
	//var myProperty='Preset';
	//var myVal = 'Joxy.preset.conf';
	//alert (myProperty);
	new Ajax.Request('/jsonrpc.js', {
		method: 'post',
		asynchronous: true,
		postBody: Object.toJSON({
			id: 1, 
			method: 'slim.request', 
			params: [
				getCurrentPlayer(), 
				[
					'SqueezeDSP.setval',
					'key:'+myProperty,
					'val:'+myVal
				]
				]
			}),
			onFailure: function() { alert('Failed') },
			onSuccess: function(response) { 	// debugger;
			var data = response.responseText.evalJSON();
			if(typeof callback !== 'undefined'){
					SqueezeDSPGetSettings(callback);
				};
			//SqueezeDSPGetSettings(LocalUpdateSettings);
			}
		});
	}

function SqueezeDSPSavePreset(myVal, callback)
{
	
	// Save this value (async)
	alert ('Saving');
	new Ajax.Request('/jsonrpc.js', {
		method: 'post',
		asynchronous: true,
		postBody: Object.toJSON({
			id: 1, 
			method: 'slim.request', 
			params: [
				getCurrentPlayer(), 
				[
					'SqueezeDSP.saveas',
					'preset:' + myVal,
				],
			]
		}),
		onFailure: function() { alert('Failed'); },

		onSuccess: function(response) {
			// debugger;
		var data = response.responseText.evalJSON();
				
		callback();
		}	});
}

function SqueezeDSPSaveEQBand(myBand, myFreq, myGain)
{
				
				new Ajax.Request('/jsonrpc.js', {
					method: 'post',
					asynchronous: true,
					postBody: Object.toJSON({
						id: 1, 
						method: 'slim.request', 
						params: [
							getCurrentPlayer(), 
							[
								'SqueezeDSP.seteq',
								'band:'+myBand,
								'freq:'+myFreq,
								'gain:'+myGain
							]
						]
					}),
					onFailure: function() { alert('Failed'); },
					onSuccess: function(response) {
					// debugger;
						var data = response.responseText.evalJSON();
					}
				});
}
