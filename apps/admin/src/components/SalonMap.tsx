'use client';

import L from 'leaflet';
import { useEffect, useMemo } from 'react';
import { MapContainer, Marker, TileLayer, ZoomControl, useMap, useMapEvents } from 'react-leaflet';

const TRIPOLI: [number, number] = [32.8872, 13.1913];
const DEFAULT_ZOOM = 15;
const NO_LOCATION_ZOOM = 11;

const pinIcon = L.divIcon({
  className: 'pin-icon',
  html: '<svg width="36" height="44" viewBox="0 0 24 30" aria-hidden="true"><path d="M12 29C12 29 22 18.5 22 11a10 10 0 1 0-20 0c0 7.5 10 18 10 18Z" fill="#D62828" stroke="#fff" stroke-width="1.5"/><circle cx="12" cy="11" r="4" fill="#fff"/></svg>',
  iconSize: [36, 44],
  iconAnchor: [18, 44],
});

function Follow({ position }: { position: [number, number] | null }) {
  const map = useMap();
  useEffect(() => {
    if (position) map.setView(position, Math.max(map.getZoom(), DEFAULT_ZOOM), { animate: false });
  }, [map, position]);
  return null;
}

function ClickToMove({ onChange }: { onChange: (lat: number, lng: number) => void }) {
  useMapEvents({ click: (event) => onChange(event.latlng.lat, event.latlng.lng) });
  return null;
}

export default function SalonMap({ latitude, longitude, onChange }: { latitude: number | null; longitude: number | null; onChange: (lat: number, lng: number) => void }) {
  const position = useMemo<[number, number] | null>(() => (latitude != null && longitude != null ? [latitude, longitude] : null), [latitude, longitude]);

  return (
    <div data-testid="salon-map">
    <MapContainer center={position ?? TRIPOLI} zoom={position ? DEFAULT_ZOOM : NO_LOCATION_ZOOM} className="h-[320px] w-full rounded-card border border-line" scrollWheelZoom zoomControl={false}>
      <ZoomControl position="topleft" zoomInTitle="تكبير" zoomOutTitle="تصغير" />
      <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
      <ClickToMove onChange={onChange} />
      <Follow position={position} />
      {position && (
        <Marker
          position={position}
          icon={pinIcon}
          title="موقع الصالون"
          alt="موقع الصالون"
          draggable
          eventHandlers={{
            dragend: (event) => {
              const { lat, lng } = (event.target as L.Marker).getLatLng();
              onChange(lat, lng);
            },
          }}
        />
      )}
    </MapContainer>
    </div>
  );
}
