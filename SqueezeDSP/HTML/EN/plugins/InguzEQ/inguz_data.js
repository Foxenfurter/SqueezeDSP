// Lets create the  InguzData object
function getCurrentPlayer()
{
   return (playerid);
}

InguzData = function()

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

function UpdateInguzData(data)
{
		InguzData.AmbRotateX = data.result['AmbRotateX'];
		InguzData.AmbRotateY =  data.result['AmbRotateY'];
		InguzData.AmbRotateZ =   data.result['AmbRotateZ'];
		InguzData.Amb =   data.result['Amb'];
		InguzData.AmbjW =   data.result['AmbjW'];
		InguzData.AmbAngle =   data.result['AmbAngle'];
		InguzData.AmbDirect =   data.result['AmbDirect'];
		InguzData.Bands =   data.result['Bands'];
		InguzData.Balance =   data.result['Balance'];
		InguzData.Skew =   data.result['Skew'];
		InguzData.Flatness =   data.result['Flatness'];
		InguzData.Quietness =   data.result['Quietness'];
		InguzData.Width =   data.result['Width'];
		
		InguzData.Matrix = data.result['Matrix'];
		InguzData.Filter = data.result['Filter'];
		InguzData.Preset = data.result['Preset'];
		
		// Copy EQ_loop
		InguzData.EQ_loop = data.result.EQ_loop;

}


function InguzGetList(callback)
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
					'inguzeq.filters'
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

function InguzGetSettings(callback)
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
					'inguzeq.current'
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

function InguzSelectPreset()
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
					'inguzeq.setval',
					'key:'+myProperty,
					'val:'+myVal
				]
				]
			}),
			onFailure: function() { alert('Failed') },
			onSuccess: function(response) { 	// debugger;
			var data = response.responseText.evalJSON();
			InguzGetSettings(LocalUpdateSettings);
			}
		});
	}

function InguzSelectValue(myProperty, myVal, callback)
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
					'inguzeq.setval',
					'key:'+myProperty,
					'val:'+myVal
				]
				]
			}),
			onFailure: function() { alert('Failed') },
			onSuccess: function(response) { 	// debugger;
			var data = response.responseText.evalJSON();
			if(typeof callback !== 'undefined'){
					InguzGetSettings(callback);
				};
			//InguzGetSettings(LocalUpdateSettings);
			}
		});
	}

function InguzSavePreset(myVal, callback)
{
	
	// Save this value (async)
	new Ajax.Request('/jsonrpc.js', {
		method: 'post',
		asynchronous: true,
		postBody: Object.toJSON({
			id: 1, 
			method: 'slim.request', 
			params: [
				getCurrentPlayer(), 
				[
					'inguzeq.saveas',
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

function InguzSaveEQBand(myBand, myFreq, myGain)
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
								'inguzeq.seteq',
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
