Config = {}

-- General garage settings
Config.UseTarget = false -- Use qb-target interactions instead of DrawText3D
Config.TransferCost = 500 -- Cost to transfer a vehicle between garages
Config.EnableImpound = true -- false to remove impound
Config.ImpoundFee = 500 -- Base fee to retrieve a vehicle from impound
Config.ShowJobVehiclesTab = true -- Show Job Vehicles tab in garage
Config.LostVehicleTimeout = 7200 -- Time in seconds before an out vehicle is considered lost (2 hours)

Config.UseDPTextUI = true -- Cambia a 'false' si quieres usar DrawText3D en lugar de DP-TextUI

Config.ImpoundJobs = {
    ['police'] = true,
    ['sheriff'] = true
}

Config.ImpounderTypes = { -- Tipos de entidades que pueden confiscar vehículos
    ["police"] = "Policía",
    ["government"] = "Gobierno",
    ["judge"] = "Corte",
    ["admin"] = "Administrador"
}

-- Configuración de los blips
Config.GarageBlip = {
    Enable = true, -- Habilitar/deshabilitar el blip
    Sprite = 357, -- Estilo del blip
    Color = 0, -- Color del blip
    Scale = 0.6, -- Tamaño del blip
    Display = 4, -- Cómo se muestra el blip
    ShortRange = true -- El blip solo aparece cuando estás cerca
}

-- Shared garage settings
Config.EnableSharedGarages = true -- Enable/disable shared garages feature
Config.MaxSharedVehicles = 15 -- Maximum vehicles per shared garage
Config.MaxSharedGarageMembers = 10 -- Maximum members per shared garage
Config.SharedGarageBlip = {
    Enable = true,
    Sprite = 357,
    Color = 5, -- Different color for shared garages (purple)
    Scale = 0.7,
    Display = 4,
    ShortRange = true
}

-- Trabajos que tienen acceso a vehículos de trabajo
Config.JobVehicleAccess = {
    ['police'] = true,
    ['ambulance'] = true,
    ['mechanic'] = true
}

-- Garajes públicos
Config.Garages = {
    ['PinkCage Motel'] = {
        label = 'PinkCage Motel', -- Nombre del garaje
        coords = vector4(275.44, -345.57, 45.17, 341), -- Coordenadas de entrada
        type = 'public',
        spawnPoints = { -- Puntos de aparición de vehículos
        vector4(270.94, -339.8, 44.92, 160.0)}
    },
    ['Casino'] = {
        label = 'Casino',
        coords = vector4(967.34, 7.45, 81.16, 58),
        type = 'public',
        spawnPoints = {vector4(961.15, 5.34, 80.72, 57)}
    },
    ['North Rockford Drive'] = {
        label = 'North Rockford Drive',
        coords = vector4(-1159.57, -739.40, 19.89, 220),
        type = 'public',
        spawnPoints = {vector4(-1154.67, -750.04, 18.68, 219)}
    },
    ['Spanish Ave'] = {
        label = 'Spanish Ave',
        coords = vector4(67.83, 12.26, 69.21, 340),
        type = 'public',
        spawnPoints = {vector4(59.29, 26.59, 69.40, 249)}
    },
    ['Clinton Ave'] = {
        label = 'Clinton Ave',
        coords = vector4(361.87, 297.84, 103.88, 338),
        type = 'public',
        spawnPoints = {vector4(375.52, 288.74, 102.77, 69)}
    },
    ['Airport'] = {
        label = 'Airport',
        coords = vector4(-787.60, -2038.23, 9.04, 317),
        type = 'public',
        spawnPoints = {vector4(-779.86, -2040.12, 8.44, 315)}
    },
    ['Magellan Ave'] = {
        label = 'Magellan Ave',
        coords = vector4(-1184.83, -1510.07, 4.65, 305),
        type = 'public',
        spawnPoints = {vector4(-1199.35, -1482.68, 3.94, 219)}
    },
    ['Rute 68'] = {
        label = 'Rute 68',
        coords = vector4(1134.56, 2665.09, 38.14, 272),
        type = 'public',
        spawnPoints = {vector4(1128.60, 2669.17, 37.61, 177)}
    },
    ['Sandy Shore'] = {
        label = 'Sandy Shore',
        coords = vector4(1987.22, 3783.25, 32.27, 118),
        type = 'public',
        spawnPoints = {vector4(1979.95, 3781.48, 31.74, 193)}
    },
    ['Paleto Bay'] = {
        label = 'Paleto Bay',
        coords = vector4(-188.15, 6230.29, 31.49, 135),
        type = 'public',
        spawnPoints = {vector4(-184.21, 6221.41, 31.05, 136)}
    },
    ['Pillbox Hill'] = {
        label = 'Pillbox Hill',
        coords = vector4(214.02, -808.49, 31.01, 154),
        type = 'public',
        spawnPoints = {vector4(230.62, -796.98, 30.17, 159)}
    },
    ['Grapeseed'] = {
        label = 'Grapeseed',
        coords = vector4(2110.37, 4775.71, 40.98, 150),
        type = 'public',
        spawnPoints = {vector4(2109.97, 4768.14, 40.79, 105)}
    }
}

-- Garajes de trabajo
Config.JobGarages = {
    ['Garaje LSPD'] = {
        label = 'Garaje LSPD',
        coords = vector4(458.53, -985.49, 25.71, 84),
        type = 'job',
        job = 'police',
        spawnPoints = { -- Puntos de aparición de vehículos
        vector4(442.29, -985.03, 25.08, 90), vector4(442.29, -988.53, 25.08, 90), vector4(442.29, -991.73, 25.08, 90),
        vector4(442.29, -995.23, 25.08, 90), vector4(426.19, -995.23, 25.08, 269), vector4(426.29, -991.63, 25.08, 270),
        vector4(426.29, -988.43, 25.08, 270), vector4(426.29, -985.03, 25.08, 270),
        vector4(426.29, -981.53, 25.08, 270), vector4(426.29, -978.23, 25.08, 270)},
        vehicles = {
            ['furiaum'] = {
                label = 'Furia Interceptor', -- Etiqueta del vehículo
                model = 'furiaum' -- Modelo del vehículo
            },
            ['polcoquette4'] = {
                label = 'Coquette D10 Interceptor',
                model = 'polcoquette4'
            },
            ['dw_sheriffcq4'] = {
                label = 'Coquette D5 Interceptor',
                model = 'dw_sheriffcq4'
            },
            ['hwaybullet'] = {
                label = 'Bullet Interceptor',
                model = 'hwaybullet'
            },
            ['polbullet2'] = {
                label = 'Bullet Unmarked',
                model = 'polbullet2'
            },
            ['hwaycarboniz'] = {
                label = 'Carbonizzare',
                model = 'hwaycarboniz'
            },
            ['polvacca'] = {
                label = 'Vacca Interceptor',
                model = 'polvacca'
            },
            ['cypherpd'] = {
                label = 'Cypher',
                model = 'cypherpd'
            },
            ['sahpcomet'] = {
                label = 'Comet',
                model = 'sahpcomet'
            },
            ['sahpgrowler'] = {
                label = 'Growler Interceptor',
                model = 'sahpgrowler'
            },
            ['sahpneon'] = {
                label = 'Neon',
                model = 'sahpneon'
            },
            ['lspdraiden'] = {
                label = 'Raiden',
                model = 'lspdraiden'
            },
            ['polfaction2'] = {
                label = 'Outreach Faction',
                model = 'polfaction2'
            },
            ['polumkcara'] = {
                label = 'Caracara Unmarked',
                model = 'polumkcara'
            },
            ['dw_beachp'] = {
                label = 'Contender 4x4',
                model = 'dw_beachp'
            },
            ['polmesa'] = {
                label = 'Mesa 4X4',
                model = 'polmesa'
            },
            ['polmesa2'] = {
                label = 'Mesa Low',
                model = 'polmesa2'
            },
            ['polcaracara'] = {
                label = 'Caracara',
                model = 'polcaracara'
            },
            ['polumkmesa'] = {
                label = 'Mesa Low Unmarked',
                model = 'polumkmesa'
            },
            ['dw_sheriffriata'] = {
                label = 'Riata',
                model = 'dw_sheriffriata'
            },
            ['dw_cgsandking'] = {
                label = 'Sandking',
                model = 'dw_cgsandking'
            },
            ['dw_sheriffsandking'] = {
                label = 'Sandking Low',
                model = 'dw_sheriffsandking'
            },
            ['dw_sheriffstalker'] = {
                label = 'Landstalker XL',
                model = 'dw_sheriffstalker'
            },
            ['polpatriot'] = {
                label = 'Patriot',
                model = 'polpatriot'
            },
            ['expolregent'] = {
                label = 'Regent',
                model = 'expolregent'
            },
            ['dw_sheriffscoutnew'] = {
                label = 'Scout I',
                model = 'dw_sheriffscoutnew'
            },
            ['expolscout'] = {
                label = 'Scout II',
                model = 'expolscout'
            },
            ['polterminus'] = {
                label = 'Terminus Patrol',
                model = 'polterminus'
            },
            ['dw_lssd2'] = {
                label = 'Granger 3500 LX',
                model = 'dw_lssd2'
            },
            ['polaleutian'] = {
                label = 'Aleutian',
                model = 'polaleutian'
            },
            ['dw_sheriffalamo'] = {
                label = 'Alamo',
                model = 'dw_sheriffalamo'
            },
            ['trualamo'] = {
                label = 'Alamo Unmarked',
                model = 'trualamo'
            },
            ['slalamo24'] = {
                label = 'Alamo 2700 LX',
                model = 'slalamo24'
            },
            ['trualamo3'] = {
                label = 'Alamo 2700 LX Unmarked',
                model = 'trualamo3'
            },
            ['dw_sheriffroamer'] = {
                label = 'Landroamer',
                model = 'dw_sheriffroamer'
            },
            ['fbi2'] = {
                label = 'Alamo Unmarked',
                model = 'fbi2'
            },
            ['polvstr'] = {
                label = 'V-STR',
                model = 'polvstr'
            },
            ['podominator'] = {
                label = 'Dominator',
                model = 'podominator'
            },
            ['poldominator10'] = {
                label = 'Dominator FX',
                model = 'poldominator10'
            },
            ['poldomgtx'] = {
                label = 'Dominator GTX',
                model = 'poldomgtx'
            },
            ['dvdt3'] = {
                label = 'Nightmare GT Unmarked',
                model = 'dvdt3'
            },
            ['polimpaler6'] = {
                label = 'Impaler LX',
                model = 'polimpaler6'
            },
            ['polimpaler5'] = {
                label = 'Impaler SZ',
                model = 'polimpaler5'
            },
            ['umkrazor'] = {
                label = 'Razor Unmarked',
                model = 'umkrazor'
            },
            ['poldorado'] = {
                label = 'Dorado',
                model = 'poldorado'
            },
            ['prevolter'] = {
                label = 'Revolter Unmarked',
                model = 'prevolter'
            },
            ['polgreenwood'] = {
                label = 'Greenwood',
                model = 'polgreenwood'
            },
            ['polgauntlet'] = {
                label = 'Gauntlet Interceptor',
                model = 'polgauntlet'
            },
            ['dw_sherifffug'] = {
                label = 'Cheval Fugitive',
                model = 'dw_sherifffug'
            },
            ['police5'] = {
                label = 'Stanier LE',
                model = 'police5'
            },
            ['police'] = {
                label = 'Stanier',
                model = 'police'
            },
            ['police4'] = {
                label = 'Stanier Unmarked',
                model = 'police4'
            },
            ['police2'] = {
                label = 'Buffalo',
                model = 'police2'
            },
            ['fbi'] = {
                label = 'Buffalo Unmarked',
                model = 'fbi'
            },
            ['dw_lspd2'] = {
                label = 'Buffalo S',
                model = 'dw_lspd2'
            },
            ['dw_police42'] = {
                label = 'Buffalo S Unmarked',
                model = 'dw_police42'
            },
            ['polbuffev'] = {
                label = 'Buffalo EVX Interceptor',
                model = 'polbuffev'
            },
            ['buffalosxpol'] = {
                label = 'Buffalo SX',
                model = 'buffalosxpol'
            },
            ['police7'] = {
                label = 'Precedente',
                model = 'police7'
            },
            ['policefelon'] = {
                label = 'Felon Unmarked',
                model = 'policefelon'
            },
            ['lspdrad'] = {
                label = 'Radius',
                model = 'lspdrad'
            },
            ['police6'] = {
                label = 'Merit ',
                model = 'police6'
            },
            ['dw_polmerit2'] = {
                label = 'Merit Unmarked',
                model = 'dw_polmerit2'
            },
            ['police3'] = {
                label = 'Interceptor',
                model = 'police3'
            },
            ['policeb'] = {
                label = 'Bike I',
                model = 'policeb'
            },
            ['dw_lspdb'] = {
                label = 'Bike II',
                model = 'dw_lspdb'
            },
            ['dw_sheriffthrust'] = {
                label = 'Thrust Sheriff',
                model = 'dw_sheriffthrust'
            },
            ['polthrust'] = {
                label = 'Thrust Police',
                model = 'polthrust'
            },
            ['dw_sheriffb3'] = {
                label = 'Manchez Scout',
                model = 'dw_sheriffb3'
            },
            ['policeb1'] = {
                label = 'Hakuchou',
                model = 'policeb1'
            },
            ['policeb2'] = {
                label = 'BF400',
                model = 'policeb2'
            },
            ['dw_sherifft'] = {
                label = 'Boxville',
                model = 'dw_sherifft'
            },
            ['riot'] = {
                label = 'Riot',
                model = 'riot'
            },
            ['riot2'] = {
                label = 'RCV',
                model = 'riot2'
            },
            ['dw_sheriffinsurgent'] = {
                label = 'Surgent',
                model = 'dw_sheriffinsurgent'
            },
            ['policet'] = {
                label = 'Transporter',
                model = 'policet'
            },
            ['swatvanr2'] = {
                label = 'Jogger Swatvan',
                model = 'swatvanr2'
            },
            ['pbus'] = {
                label = 'Prison Bus',
                model = 'pbus'
            }
        }
    },
    ['Garaje EMS'] = {
        label = 'Garaje Medico',
        coords = vector4(327.14, -558.78, 28.74, 339.54),
        type = 'job',
        job = 'ambulance',
        spawnPoint = vector4(320.84, -548.9, 28.74, 180.0),
        vehicles = {
            ['ambulance'] = {
                label = 'Ambulance',
                model = 'ambulance'
            }
        }
    },
    ['Garaje MCH'] = {
        label = 'Garaje MCH',
        coords = vector4(-344.94, -124.4, 39.01, 339.54),
        type = 'job',
        job = 'mechanic',
        spawnPoint = vector4(-350.85, -136.39, 39.01, 70.29),
        vehicles = {
            ['towtruck'] = {
                label = 'Tow Truck',
                model = 'towtruck'
            },
            ['flatbed'] = {
                label = 'Flatbed',
                model = 'flatbed'
            }
        }
    }
}

-- Garajes de bandas
Config.GangGarages = {
    ['Garaje Ballas'] = {
        label = 'Garaje Ballas',
        coords = vector4(118.25, -1944.15, 20.67, 77),
        type = 'gang',
        gang = 'ballas',
        spawnPoint = vector4(116.78, -1949.36, 20.29, 52)
    },
    ['Garaje Families'] = {
        label = 'Garaje Families',
        coords = vector4(-205.59, -1546.32, 34.11, 49),
        type = 'gang',
        gang = 'families',
        spawnPoint = vector4(-195.89, -1532.99, 33.39, 321)
    },
    ['Garaje Lost Motor Club'] = {
        label = 'Garaje Lost Motor Club',
        coords = vector4(40.31, 2776.93, 57.88, 338),
        type = 'gang',
        gang = 'lostmc',
        spawnPoint = vector4(52.51, 2771.20, 57.47, 233)
    },
    ['Garaje La Omertà'] = {
        label = 'Garaje La Omertà',
        coords = vector4(801.26, 1272.02, 343.99, 109),
        type = 'gang',
        gang = 'omerta',
        spawnPoint = vector4(805.67, 1270.69, 343.51, 108)
    }
}

-- Lotes de confiscación (Impound)
Config.ImpoundLots = {
    ['mission_row'] = {
        label = 'Depósito', -- Etiqueta del depósito
        coords = vector4(408.97, -1622.74, 29.29, 233), -- Coordenadas de entrada
        blip = { -- Configuración del blip del depósito
            sprite = 68,
            color = 0,
            scale = 0.6,
            display = 4,
            shortRange = true
        },
        spawnPoints = { -- Puntos de aparición para vehículos del depósito
        vector4(401.09, -1631.90, 28.85, 142)}
    },
    ['paleto'] = {
        label = 'Depósito',
        coords = vector4(-289.41, 6117.82, 31.63, 354),
        blip = {
            sprite = 68,
            color = 0,
            scale = 0.6,
            display = 4,
            shortRange = true
        },
        spawnPoints = {vector4(-308.28, 6108.39, 31.06, 319)}
    },
    ['sandy'] = {
        label = 'Depósito',
        coords = vector4(1879.54, 3764.56, 32.93, 204),
        blip = {
            sprite = 68,
            color = 0,
            scale = 0.6,
            display = 4,
            shortRange = true
        },
        spawnPoints = {vector4(1886.35, 3762.75, 32.34, 188)}
    }
}
