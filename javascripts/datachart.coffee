$ = jQuery

$(document).ready ->
    elements = $(".container")
    loaddata element for element in elements
  
loaddata = (e) ->
    file = $(e).attr("data-files")
    if file.lastIndexOf(".tcx") > 0
        parserType = "TCX"
    else if file.lastIndexOf(".slf") > 0
        parserType = "SIGMA"
    else
        parserType = "UNKNOWN"
    $.get(file).complete (data) ->
        createchart(data.responseText, e, parserType)

getParser = (parserType, xmlDoc) ->
    switch parserType
        when "TCX" then p = new TCXDataParser xmlDoc
        when "SIGMA" then p = new SigmaDataParser xmlDoc
        else p = null

createchart = (x, element, parserType) ->
    xml = $.parseXML(x)
    xmlDoc = $(xml)
    dataparser = getParser parserType, xmlDoc
    if dataparser
        container = $(element).attr("id")
        chartOptions = {
            chart: { renderTo: container, zoomType: 'x' }
            title: { text: null }
            subtitle: {
                text: 'Click and drag in the plot area to zoom in'
                #text: if $.contains(document.documentElement, 'ontouchstart') then 'Drag your finger over the plot to zoom in' else 'Click and drag in the plot area to zoom in'
            }
            xAxis: {
                title: { text: null },
                type: 'linear',
                minRange: 5,
                labels: {
                    formatter: () ->
                        v = convertToKm this.value
                        f = "#{v} km"
                }
            }
            yAxis: [
                {
                    title: { text: null },
                    endOnTick: false
                },
                {
                    title: { text: null },
                    endOnTick: false
                }
            ]
            tooltip: {
                formatter: () ->
                    if this.series.name == 'Elevation'
                        x = convertToKm this.x
                        y = extround this.y, 100
                        t = "<strong>Distance:</strong> #{x} km<br /><strong>Elevation:</strong> #{y} m"
                    else if this.series.name == 'Pace'
                        x = convertToKm this.x
                        y = extround this.y, 100
                        t = "<strong>Distance:</strong> #{x} km<br /><strong>Pace:</strong> #{y} km/h"
                    else if this.series.name == 'Heartrate'
                        x = convertToKm this.x
                        y = extround this.y, 100
                        t = "<strong>Distance:</strong> #{x} km<br /><strong>Heartrate:</strong> #{y}"
            }
            legend: { enabled: false }
            plotOptions: {
                spline: {
                    lineWidth: 2,
                    marker: { enabled: false, states: { hover: { enabled: true, radius: 4 } } },
                    shadow: true,
                    states: { hover: { lineWidth: 3 } }
                }
                area: {
                    fillColor: { linearGradient: { x1: 0, y1: 0, x2: 0, y2: 1}, stops: [[0, 'rgba(230,230,230,0.5)'], [1, 'rgba(150,150,150,0.5)']] },
                    lineWidth: 1,
                    lineColor: '#666666',
                    marker: { enabled: false, states: { hover: { enabled: true, radius: 4 } } },
                    shadow: true,
                    states: { hover: { lineWidth: 2 } }
                }
            }
            series: []
        }
        if dataparser.hasElevation()
            chartOptions.series.push({
                type: 'area',
                name: 'Elevation',
                data: dataparser._elevation,
                yAxis: 0
            })
        chartOptions.series.push({
            type: 'spline'
            name: 'Pace',
            color: '#06ABF3'
            data: dataparser._pace,
            yAxis: 1
        })
        if dataparser.hasHeartrate()
            chartOptions.series.push({
                type: 'spline',
                name: 'Heartrate',
                color: '#730000'
                data: dataparser._heartrate,
                yAxis: 0
            })
        c = new Highcharts.Chart(chartOptions)

extround = (number, n_stelle) ->
    z = Math.round(number * n_stelle) / n_stelle

convertToKm = (m) ->
    km = extround m / 1000, 100

convertToKmH = (ms) ->
	kmh = extround(ms * 60 * 60 / 1000, 100)

degToRad = (deg) ->
    r = deg * Math.PI / 180
    
# thanks to:
#   http://gpx.tomaskafka.com
#   https://github.com/tkafka/Javascript-GPX-track-viewer
#   http://www.movable-type.co.uk/scripts/latlong.html
pointDistance = (pnt1, pnt2) ->
    lat1 = pnt1.lat
    lon1 = pnt1.lon
    lat2 = pnt2.lat
    lon2 = pnt2.lon
	# km
    R = 6371
    dLat = Math.sin(degToRad(lat2-lat1) / 2)
    dLon = Math.sin(degToRad(lon2-lon1) / 2)
    a = dLat * dLat + Math.cos(degToRad(lat1)) * Math.cos(degToRad(lat2)) * dLon * dLon
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    # km
    R * c

class DataParser
    constructor: (@xmlDoc) ->
        @_elevation = []
        @_pace = []
        @_heartrate = []
        @parseXml()
    
    parseXml: () ->
        points = @getPoints()
        i = 0
        j = 0
        lastpnt = @parseTrackPoint(points[0])
        elevation = 0
        pace = 0
        heartrate = 0
        for i in [1...points.length]
            p = @parseTrackPoint(points[i], lastpnt)
            # length -> km and height -> m
            elevation += p.elevation
            pace += p.pace
            heartrate += p.heartrate
            mod = @dataPoints2Pack()
            if i % mod == 0
                @_elevation[j] = [p.distance, elevation / mod]
                @_heartrate[j] = [p.distance, heartrate / mod]
                @_pace[j++] = [p.distance, pace / mod]
                elevation = 0
                pace = 0
                heartrate = 0
            lastpnt = p
            
    dataPoints2Pack: () -> 5
    getPoints: () ->
    parseTrackPoint: (trackpoint, lastpnt) ->
    hasElevation: () ->
        if @_elevation && @_elevation.length > 0
            a = @_elevation.filter (x) -> x.length > 1 && x[1] > 0
            a.length > 0
        else
          false
    hasHeartrate: () ->
        if @_heartrate && @_heartrate.length > 0
            a = @_heartrate.filter (x) -> x.length > 1 && x[1] > 0
            a.length > 0
        else
          false

class TCXDataParser extends DataParser
    getPoints: () ->
        @xmlDoc.find("Trackpoint")
    
    parseTrackPoint: (trackpoint, lastpnt) ->
        p = {}
        # length -> km and height -> m
        p.distance = parseFloat($(trackpoint).find("DistanceMeters").text())
        p.elevation = parseFloat($(trackpoint).find("AltitudeMeters").text())
        p.time = Date.parse($(trackpoint).find("Time").text())
        p.lat = parseFloat($(trackpoint).find("LatitudeDegrees").text())
        p.lon = parseFloat($(trackpoint).find("LongitudeDegrees").text())
        p.pace = 0
        if lastpnt
            timediff = p.time - lastpnt.time
            if timediff > 0
                dst = pointDistance(lastpnt, p)
                p.pace = dst / timediff * 1000 * 60 * 60
        return p

class SigmaDataParser extends DataParser
    dataPoints2Pack: () -> 1
    
    getPoints: () ->
        @xmlDoc.find("LogEntry")
    
    parseTrackPoint: (trackpoint, lastpnt) ->
        p = {}
        # m
        distance = $(trackpoint).find("DistanceAbsolute").text()
        if distance
            p.distance = parseFloat(distance)
        else
            # rox91
            p.distance = 0
            if lastpnt
                p.distance = lastpnt.distance
                distance = $(trackpoint).find("Distance").text()
                p.distance += if distance then parseFloat(distance) else 0
        # m/s
        p.pace = parseFloat($(trackpoint).find("Speed").text())
        # sec
        time = $(trackpoint).find("Time").text()
        if not time
          # rox91
          time = $(trackpoint).find("RideTime").text()
        if time then p.time = parseFloat(time) else 0
        # m
        elevation = $(trackpoint).find("Altitude").text()
        p.elevation = if elevation then parseFloat(elevation) else 0
        heartrate = $(trackpoint).find("Heartrate").text()
        p.heartrate = if heartrate then parseFloat(heartrate) else 0
        return p
