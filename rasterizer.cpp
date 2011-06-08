#include "rasterizer.h"

Color Tex2DSampler::sample(const Surface* pSurface, float u, float v) const
{
	//FPInt minuteScale;
	//minuteScale.fraction = 0xffff; //same as 65535/65536

	u *= 0.99999f;//minuteScale; //scale from (0.0)-(1.0) to (0.0)-(0.99999...)
	//u.whole = 0; //remove all whole numbers and negative references, keeping fraction
	u *= pSurface->width;//FPInt(pSurface->width); //scale from (0.0)-(0.9999...) to (0)-(surface.width-1)

	v *= 0.99999f;//minuteScale; //scale from (0.0)-(1.0) to (0.0)-(0.99999...)
	//u.whole = 0; //remove all whole numbers and negative references, keeping fraction
	v *= pSurface->height;//FPInt(pSurface->height); //scale from (0.0)-(0.9999...) to (0)-(surface.width-1)

	Color color;
	if(pSurface->format == SFMT_P8)
		color = pSurface->pPaletteData[(int)v * pSurface->width + (int)u] & 0xff;
	else if(pSurface->format == SFMT_A8R8G8B8)
		color = pSurface->pColorData[(int)v * pSurface->width + (int)u];

	return color;
}



void LineSegment::calculateLineSegment(const Position &A, const Position &B)
{
	m_dx = A.x - B.x;
	m_dy = A.y - B.y;

	if((m_dx < 0 ? -m_dx : m_dx) > (m_dy < 0 ? -m_dy : m_dy))
	{
		m_isFunctionOfX = true;
		m_slope = m_dy / m_dx;
		m_yIntercept = A.y - m_slope * A.x;
	}
	else
	{
		m_isFunctionOfX = false;
		m_slope = m_dx / m_dy;
		m_xIntercept = A.x - m_slope * A.y;
	}
	m_leastX = A.x < B.x ? A.x : B.x;
	m_greatestX = A.x > B.x ? A.x : B.x;
	m_leastY = A.y < B.y ? A.y : B.y;
	m_greatestY = A.y > B.y ? A.y : B.y;
}

bool LineSegment::intersects(float *pIntersection, float YIntercept)
{
	if(YIntercept > m_greatestY || YIntercept < m_leastY)
		return false;

	if(pIntersection == 0)
		return true;

	if(m_isFunctionOfX)
	{
		if(m_slope == 0.0f || m_slope == -0.0f)
			*pIntersection = m_leastX;
		else
			*pIntersection = (YIntercept - m_yIntercept) / m_slope;
	}
	else
		*pIntersection = m_slope * YIntercept + m_xIntercept;

	return true;
}



void TriRasterizer::calculateTriangleRect(ClippingRect &clipOut, const Triangle* pTriangle)
{
	clipOut.left = (pTriangle->pnt[0].pos.x < pTriangle->pnt[1].pos.x ? pTriangle->pnt[0].pos.x : pTriangle->pnt[1].pos.x);
	clipOut.left = (pTriangle->pnt[2].pos.x < (float)clipOut.left ? pTriangle->pnt[2].pos.x : clipOut.left);

	clipOut.right = (pTriangle->pnt[0].pos.x > pTriangle->pnt[1].pos.x ? pTriangle->pnt[0].pos.x : pTriangle->pnt[1].pos.x);
	clipOut.right = (pTriangle->pnt[2].pos.x > (float)clipOut.right ? pTriangle->pnt[2].pos.x : clipOut.right);

	clipOut.top = (pTriangle->pnt[0].pos.y < pTriangle->pnt[1].pos.y ? pTriangle->pnt[0].pos.y : pTriangle->pnt[1].pos.y);
	clipOut.top = (pTriangle->pnt[2].pos.y < (float)clipOut.top ? pTriangle->pnt[2].pos.y : clipOut.top);

	clipOut.bottom = (pTriangle->pnt[0].pos.y > pTriangle->pnt[1].pos.y ? pTriangle->pnt[0].pos.y : pTriangle->pnt[1].pos.y);
	clipOut.bottom = (pTriangle->pnt[2].pos.y > (float)clipOut.bottom ? pTriangle->pnt[2].pos.y : clipOut.bottom);
}

void TriRasterizer::interpolateVertices(Vertex &vertexOut, const Vertex &v1, const Vertex &v2, float scale)
{
	Vertex out;
	float invScale(-scale + 1);

	out.pos.x = scale * v1.pos.x + invScale * v2.pos.x;
	out.pos.y = scale * v1.pos.y + invScale * v2.pos.y;
	out.tex.u = scale * v1.tex.u + invScale * v2.tex.u;
	out.tex.v = scale * v1.tex.v + invScale * v2.tex.v;
	out.col.a = scale * v1.col.a + invScale * v2.col.a;
	out.col.r = scale * v1.col.r + invScale * v2.col.r;
	out.col.g = scale * v1.col.g + invScale * v2.col.g;
	out.col.b = scale * v1.col.b + invScale * v2.col.b;

	vertexOut = out;
}

void TriRasterizer::calculateRasterPixels(const Surface* pSurface, const Triangle *pTriangle, ClippingRect& clip)
{
	//FPInt xIntercept[3];

	////figure all x-intercepts
	//FPInt deltaX, deltaY, slope, yIntercept;
	//Position a, b;

	//for(int i = 0; i < 3; i++)
	//{
	//	a = pTriangle->pnt[i].pos;
	//	b = pTriangle->pnt[(i+1)%3].pos;
	//	deltaX = a.x - b.x;
	//	deltaY = a.y - b.y;

	//	if((deltaY < 0 ? -deltaY : deltaY) > (deltaX < 0 ? -deltaX : deltaX))
	//	{//y changes more than x: use y as denominator for slope, etc.
	//		slope = deltaX / deltaY;
	//		xIntercept[i] = a.x - slope * (a.y-row);
	//	}
	//	else
	//	{//x changes more than y: use that as denominator for slope, etc.
	//		slope = deltaY / deltaX;
	//		yIntercept = a.y - slope * a.x;
	//		if(slope == 0) //0 slope
	//		{
	//			if(yIntercept == row) //entire row is to be rasterized (line is parallel with this rasterizing line AND overlays it)
	//			{
	//				xIntercept[i] = a.x;
	//				xIntercept[(i+1)%3] = b.x;
	//				break;
	//			}
	//		}
	//		else
	//		{
	//			xIntercept[i] = (-yIntercept + row) / slope;
	//		}
	//	}
	//}

	////figure leftmost and rightmost x-intercepts within the triangle minimum and maximum:
	////those are the boundaries of the raster line
	//FPInt leftMost(maximum+1), rightMost(minimum-1);
	//int leftIndex(0), rightIndex(1);
	//for(int i = 0; i < 3; i++)
	//{
	//	if(xIntercept[i]/*.whole*/ >= (minimum-1/*.whole-1*/) && xIntercept[i]/*.whole*/ <= (maximum+1/*.whole+1*/))
	//	{
	//		if(xIntercept[i] < leftMost)
	//		{
	//			leftMost = xIntercept[i];
	//			leftIndex = i;
	//		}
	//		if(xIntercept[i] > rightMost)
	//		{
	//			rightMost = xIntercept[i];
	//			rightIndex = i;
	//		}
	//	}
	//}

	////generate boundaries of raster line
	//Vertex leftBoundary, rightBoundary;

	//FPInt scale;
	//deltaX = pTriangle->pnt[leftIndex].pos.x - pTriangle->pnt[(leftIndex+1)%3].pos.x;
	//deltaY = pTriangle->pnt[leftIndex].pos.y - pTriangle->pnt[(leftIndex+1)%3].pos.y;

	//if((deltaX < 0 ? -deltaX : deltaX) > (deltaY < 0 ? -deltaY : deltaY)) //ensure the larger scale is used
	//{
	//	scale = (xIntercept[leftIndex] - pTriangle->pnt[(leftIndex+1)%3].pos.x) / deltaX;
	//}
	//else
	//{
	//	scale = (FPInt(row) - pTriangle->pnt[(leftIndex+1)%3].pos.y) / deltaY;
	//}

	//interpolateVertices(leftBoundary, pTriangle->pnt[leftIndex], pTriangle->pnt[(leftIndex+1)%3], scale);
	//leftBoundary.pos.y = row;

	//deltaX = pTriangle->pnt[rightIndex].pos.x - pTriangle->pnt[(rightIndex+1)%3].pos.x;
	//deltaY = pTriangle->pnt[rightIndex].pos.y - pTriangle->pnt[(rightIndex+1)%3].pos.y;

	//if((deltaX < 0 ? -deltaX : deltaX) > (deltaY < 0 ? -deltaY : deltaY)) //ensure the larger scale is used
	//{
	//	scale = (xIntercept[rightIndex] - pTriangle->pnt[(rightIndex+1)%3].pos.x) / deltaX;
	//}
	//else
	//{
	//	scale = (FPInt(row) - pTriangle->pnt[(rightIndex+1)%3].pos.y) / deltaY;
	//}

	//interpolateVertices(rightBoundary, pTriangle->pnt[rightIndex], pTriangle->pnt[(rightIndex+1)%3], scale);
	//rightBoundary.pos.y = row;

	////perform clipping interpolation
	//if(leftBoundary.pos.x >= pSurface->width || rightBoundary.pos.x < 0)
	//	return; //completely outside of raster area

	//if(leftBoundary.pos.x < 0)
	//{
	//	scale = leftBoundary.pos.x / (leftBoundary.pos.x - rightBoundary.pos.x);
	//	interpolateVertices(leftBoundary, leftBoundary, rightBoundary, -scale+1);
	//	leftBoundary.pos.x = 0;
	//	leftBoundary.pos.y = row;
	//}
	//if(rightBoundary.pos.x >= pSurface->width)
	//{
	//	scale = (FPInt(pSurface->width - 1) - rightBoundary.pos.x) / (leftBoundary.pos.x - rightBoundary.pos.x);
	//	interpolateVertices(rightBoundary, rightBoundary, leftBoundary, scale);
	//	rightBoundary.pos.x = pSurface->width - 1;
	//	rightBoundary.pos.y = row;
	//}

	////post the raster line
	//m_rasterLines.push( DrawingRange(leftBoundary, rightBoundary) );


	//float xIntercept[3];

	////figure all x-intercepts
	//float deltaX, deltaY, slope, yIntercept;
	//Position a, b;

	//for(int i = 0; i < 3; i++)
	//{
	//	a = pTriangle->pnt[i].pos;
	//	b = pTriangle->pnt[(i+1)%3].pos;
	//	deltaX = a.x - b.x;
	//	deltaY = a.y - b.y;

	//	if((deltaY < 0 ? -deltaY : deltaY) > (deltaX < 0 ? -deltaX : deltaX))
	//	{//y changes more than x: use y as denominator for slope, etc.
	//		slope = deltaX / deltaY;
	//		yIntercept = a.x - slope * a.y;
	//		xIntercept[i] = slope * row + yIntercept; //here, yIntercept is actually the x-intercept, and xIntercept is the intersection of the row and the line
	//	}
	//	else
	//	{//x changes more than y: use that as denominator for slope, etc.
	//		slope = deltaY / deltaX;
	//		yIntercept = a.y - slope * a.x;
	//		if(slope == 0) //0 slope
	//		{
	//			if(yIntercept == row) //entire row is to be rasterized (line is parallel with this rasterizing line AND overlays it)
	//			{
	//				xIntercept[i] = a.x;
	//				xIntercept[(i+1)%3] = b.x;
	//				break;
	//			}
	//			else
	//				xIntercept[i] = 0; //this should never happen
	//		}
	//		else
	//		{
	//			xIntercept[i] = (-yIntercept + row) / slope;
	//		}
	//	}
	//}

	////figure leftmost and rightmost x-intercepts within the triangle minimum and maximum:
	////those are the boundaries of the raster line
	//float leftMost(maximum+1), rightMost(minimum-1);
	//int leftIndex(0), rightIndex(1);
	//for(int i = 0; i < 3; i++)
	//{
	//	if(xIntercept[i]/*.whole*/ >= (float)(minimum-1/*.whole-1*/) && xIntercept[i]/*.whole*/ <= (float)(maximum+1/*.whole+1*/))
	//	{
	//		if(xIntercept[i] < leftMost)
	//		{
	//			leftMost = xIntercept[i];
	//			leftIndex = i;
	//		}
	//		if(xIntercept[i] > rightMost)
	//		{
	//			rightMost = xIntercept[i];
	//			rightIndex = i;
	//		}
	//	}
	//}

	////generate boundaries of raster line
	//Vertex leftBoundary, rightBoundary;

	//float scale;
	//deltaX = pTriangle->pnt[leftIndex].pos.x - pTriangle->pnt[(leftIndex+1)%3].pos.x;
	//deltaY = pTriangle->pnt[leftIndex].pos.y - pTriangle->pnt[(leftIndex+1)%3].pos.y;

	//if((deltaX < 0 ? -deltaX : deltaX) > (deltaY < 0 ? -deltaY : deltaY)) //ensure the larger scale is used
	//{
	//	scale = (xIntercept[leftIndex] - pTriangle->pnt[(leftIndex+1)%3].pos.x) / deltaX;
	//}
	//else
	//{
	//	scale = ((row) - pTriangle->pnt[(leftIndex+1)%3].pos.y) / deltaY;
	//}

	//interpolateVertices(leftBoundary, pTriangle->pnt[leftIndex], pTriangle->pnt[(leftIndex+1)%3], scale);
	//leftBoundary.pos.y = row;

	//deltaX = pTriangle->pnt[rightIndex].pos.x - pTriangle->pnt[(rightIndex+1)%3].pos.x;
	//deltaY = pTriangle->pnt[rightIndex].pos.y - pTriangle->pnt[(rightIndex+1)%3].pos.y;

	//if((deltaX < 0 ? -deltaX : deltaX) > (deltaY < 0 ? -deltaY : deltaY)) //ensure the larger scale is used
	//{
	//	scale = (xIntercept[rightIndex] - pTriangle->pnt[(rightIndex+1)%3].pos.x) / deltaX;
	//}
	//else
	//{
	//	scale = ((row) - pTriangle->pnt[(rightIndex+1)%3].pos.y) / deltaY;
	//}

	//interpolateVertices(rightBoundary, pTriangle->pnt[rightIndex], pTriangle->pnt[(rightIndex+1)%3], scale);
	//rightBoundary.pos.y = row;

	////perform clipping interpolation
	//if(leftBoundary.pos.x >= pSurface->width || rightBoundary.pos.x < 0)
	//	return; //completely outside of raster area

	//if(leftBoundary.pos.x < 0)
	//{
	//	scale = leftBoundary.pos.x / (leftBoundary.pos.x - rightBoundary.pos.x);
	//	interpolateVertices(leftBoundary, leftBoundary, rightBoundary, -scale+1);
	//	leftBoundary.pos.x = 0;
	//	leftBoundary.pos.y = row;
	//}
	//if(rightBoundary.pos.x >= pSurface->width)
	//{
	//	scale = ((pSurface->width - 1) - rightBoundary.pos.x) / (leftBoundary.pos.x - rightBoundary.pos.x);
	//	interpolateVertices(rightBoundary, rightBoundary, leftBoundary, scale);
	//	rightBoundary.pos.x = pSurface->width - 1;
	//	rightBoundary.pos.y = row;
	//}

	////post the raster line
	//m_rasterLines.push( DrawingRange(leftBoundary, rightBoundary) );

	//check that the clipping rect is within the surface's boundaries
	if(clip.left < 0.0f) clip.left = 0.0f;
	if(clip.right > pSurface->width-1) clip.right = pSurface->width-1;
	if(clip.top < 0.0f) clip.top = 0.0f;
	if(clip.bottom > pSurface->height-1) clip.bottom = pSurface->height-1;

	//check if triangle is out of range of the clipping rect
	ClippingRect triangleRect = {pTriangle->pnt[0].pos.x, pTriangle->pnt[0].pos.y, pTriangle->pnt[0].pos.x, pTriangle->pnt[0].pos.y};
	for(int i = 1; i < 3; i++)
	{
		if(pTriangle->pnt[i].pos.x < triangleRect.left)
			triangleRect.left = pTriangle->pnt[i].pos.x;
		if(pTriangle->pnt[i].pos.x > triangleRect.right)
			triangleRect.right = pTriangle->pnt[i].pos.x;
		if(pTriangle->pnt[i].pos.y < triangleRect.top)
			triangleRect.top = pTriangle->pnt[i].pos.y;
		if(pTriangle->pnt[i].pos.y > triangleRect.bottom)
			triangleRect.bottom = pTriangle->pnt[i].pos.y;
	}

	if(triangleRect.left > clip.right || triangleRect.right < clip.left || triangleRect.top > clip.bottom || triangleRect.bottom < clip.top)
		return;

	//calculate the edge lines of the triangle
	LineSegment segments[3];
	for(int i = 0; i < 3; i++)
		segments[i].calculateLineSegment(pTriangle->pnt[i].pos, pTriangle->pnt[(i+1)%3].pos);

	//find the left and right boundaries of each raster line
	float xIntersection[3];
	float leftMost, rightMost;
	int leftMostIndex, rightMostIndex;
	float scale;
	Vertex leftVertex, rightVertex;
	for(int row = (clip.top > triangleRect.top ? clip.top : triangleRect.top),
		    rowEnd = (clip.bottom < triangleRect.bottom ? clip.bottom : triangleRect.bottom);
			row <= rowEnd; row++)
	{
		leftMost = triangleRect.right + 1.0f;
		leftMostIndex = -1;
		rightMost = triangleRect.left - 1.0f;
		rightMostIndex = -1;
		for(int i = 0; i < 3; i++)
		{
			if(!segments[i].intersects(&xIntersection[i], row))
				continue;
			if(xIntersection[i] < triangleRect.left || xIntersection[i] > triangleRect.right)
				continue;
			if(xIntersection[i] < leftMost)
			{
				leftMost = xIntersection[i];
				leftMostIndex = i;
			}
			if(xIntersection[i] > rightMost)
			{
				rightMost = xIntersection[i];
				rightMostIndex = i;
			}
		}

		if(leftMostIndex == -1 || rightMostIndex == -1)
			continue;

		//interpolate vertex data for each line
		//this part needs fixing, then it's done! I think...

		//if(segments[leftMostIndex].isFunctionOfX())
		//{
		//	if(segments[leftMostIndex].dx() == 0.0f || segments[leftMostIndex].dx() == -0.0f)
		//		scale = 1.0f;
		//	else
		//		scale = (xIntersection[leftMostIndex] - pTriangle->pnt[(leftMostIndex+1)%3].pos.x) / segments[leftMostIndex].dx();
		//}
		//else
		//{
		//	if(segments[leftMostIndex].dy() == 0.0f || segments[leftMostIndex].dy() == -0.0f)
		//		scale = 1.0f;
		//	else
		//		scale = (xIntersection[leftMostIndex] - pTriangle->pnt[(leftMostIndex+1)%3].pos.y) / segments[leftMostIndex].dy();
		//}
		//interpolateVertices(leftVertex, pTriangle->pnt[leftMostIndex], pTriangle->pnt[(leftMostIndex+1)%3], .5f);
		leftVertex = pTriangle->pnt[leftMostIndex];
		leftVertex.pos.x = xIntersection[leftMostIndex];
		leftVertex.pos.y = row;

		//if(segments[rightMostIndex].isFunctionOfX())
		//{
		//	if(segments[rightMostIndex].dx() == 0.0f || segments[rightMostIndex].dx() == -0.0f)
		//		scale = 1.0f;
		//	else
		//		scale = (xIntersection[rightMostIndex] - pTriangle->pnt[(rightMostIndex+1)%3].pos.x) / segments[rightMostIndex].dx();
		//}
		//else
		//{
		//	if(segments[rightMostIndex].dy() == 0.0f || segments[rightMostIndex].dy() == -0.0f)
		//		scale = 1.0f;
		//	else
		//		scale = (xIntersection[rightMostIndex] - pTriangle->pnt[(rightMostIndex+1)%3].pos.y) / segments[rightMostIndex].dy();
		//}
		//interpolateVertices(rightVertex, pTriangle->pnt[rightMostIndex], pTriangle->pnt[(rightMostIndex+1)%3], .5f);
		rightVertex = pTriangle->pnt[rightMostIndex];
		rightVertex.pos.x = xIntersection[rightMostIndex];
		rightVertex.pos.y = row;

		//perform horizontal clipping
		if(leftVertex.pos.x > clip.right || rightVertex.pos.x < clip.left)
			continue;
		
		if(leftVertex.pos.x < clip.left)
		{
			scale = (clip.left - leftVertex.pos.x) / (rightVertex.pos.x - leftVertex.pos.x);
			interpolateVertices(leftVertex, leftVertex, rightVertex, 1-scale);
			leftVertex.pos.x = clip.left;
			leftVertex.pos.y = row;
		}
		if(rightVertex.pos.x > clip.right)
		{
			scale = (clip.right - rightVertex.pos.x) / (leftVertex.pos.x - rightVertex.pos.x);
			interpolateVertices(rightVertex, rightVertex, leftVertex, 1-scale);
			rightVertex.pos.x = clip.right;
			rightVertex.pos.y = row;
		}

		//push the data onto the raster queue
		m_rasterLines.push( DrawingRange(leftVertex, rightVertex) );
	}
}

void TriRasterizer::rasterColor(Surface *pSurface, const DrawingRange &range, const Triangle *pTriangle)
{
	Color color;
	float length(range.greatest.pos.x - range.least.pos.x+1), 
		  weightFirst,
		  weightSecond;

	int start = 0, finish = 0;

	start = (range.least.pos.x < 0 ? 0 : range.least.pos.x);
	finish = (range.greatest.pos.x >= pSurface->width ? pSurface->width-1 : range.greatest.pos.x);

	for(int i = start; i <= finish; i++)
	{
		weightFirst = (range.greatest.pos.x - i) / (float)length;
		weightSecond = 1 - weightFirst;

		if(pSurface->format == SFMT_P8)
		{
			color.b = weightFirst * range.least.col.b + weightSecond * range.greatest.col.b;
			pSurface->pPaletteData[(int)range.least.pos.y * pSurface->width + i] = (SurfaceData8)color;
		}
		else
		{
			color.a = weightFirst * range.least.col.a + weightSecond * range.greatest.col.a;
			color.r = weightFirst * range.least.col.r + weightSecond * range.greatest.col.r;
			color.g = weightFirst * range.least.col.g + weightSecond * range.greatest.col.g;
			color.b = weightFirst * range.least.col.b + weightSecond * range.greatest.col.b;
			pSurface->pColorData[(int)range.least.pos.y * pSurface->width + i] = (SurfaceData32)color;
		}
	}
}

void TriRasterizer::rasterTexture(Surface *pSurface, const DrawingRange &range, const Triangle *pTriangle, const Surface *pTexture)
{
	TexCoord texel;
	float length(range.greatest.pos.x - range.least.pos.x+1), 
		  weightFirst,
		  weightSecond;

	int start = 0, finish = 0;

	start = (range.least.pos.x < 0 ? 0 : range.least.pos.x);
	finish = (range.greatest.pos.x >= pSurface->width ? pSurface->width-1 : range.greatest.pos.x);

	for(int i = start; i <= finish; i++)
	{
		weightFirst = (range.greatest.pos.x - i) / (float)length;
		weightSecond = 1 - weightFirst;
		texel.u = weightFirst * range.least.tex.u + weightSecond * range.greatest.tex.u;
		texel.v = weightFirst * range.least.tex.v + weightSecond * range.greatest.tex.v;

		if(pSurface->format == SFMT_P8)
		{
			pSurface->pPaletteData[(int)range.least.pos.y * pSurface->width + i] = (SurfaceData8)m_sampler.sample(pTexture, texel.u, texel.v);
		}
		else
		{
			pSurface->pColorData[(int)range.least.pos.y * pSurface->width + i] = (SurfaceData32)m_sampler.sample(pTexture, texel.u, texel.v);
		}
	}
}

void TriRasterizer::rasterTextureColor(Surface *pSurface, const DrawingRange &range, const Triangle *pTriangle, const Surface *pTexture)
{
	TexCoord texel;
	Color texelColor;
	Color color;
	float length(range.greatest.pos.x - range.least.pos.x+1), 
		  weightFirst,
		  weightSecond;

	int start = 0, finish = 0;

	start = (range.least.pos.x < 0 ? 0 : range.least.pos.x);
	finish = (range.greatest.pos.x >= pSurface->width ? pSurface->width-1 : range.greatest.pos.x);

	for(int i = start; i <= finish; i++)
	{
		weightFirst = (range.greatest.pos.x - i) / (float)length;
		weightSecond = 1 - weightFirst;
		texel.u = weightFirst * range.least.tex.u + weightSecond * range.greatest.tex.u;
		texel.v = weightFirst * range.least.tex.v + weightSecond * range.greatest.tex.v;

		if(pSurface->format == SFMT_P8) //no point for palettes to be affected by color weights
		{
			pSurface->pPaletteData[(int)range.least.pos.y * pSurface->width + i] = (SurfaceData8)m_sampler.sample(pTexture, texel.u, texel.v);
		}
		else
		{
			texelColor = m_sampler.sample(pTexture, texel.u, texel.v);
			color.a = ((int)(weightFirst * range.least.col.a + weightSecond * range.greatest.col.a) * texelColor.a) >> 8;
			color.r = ((int)(weightFirst * range.least.col.r + weightSecond * range.greatest.col.r) * texelColor.r) >> 8;
			color.g = ((int)(weightFirst * range.least.col.g + weightSecond * range.greatest.col.g) * texelColor.g) >> 8;
			color.b = ((int)(weightFirst * range.least.col.b + weightSecond * range.greatest.col.b) * texelColor.b) >> 8;
			pSurface->pColorData[(int)range.least.pos.y * pSurface->width + i] = (SurfaceData32)color;
		}
	}
}

void TriRasterizer::drawTest(Surface* pSurface, const Triangle* pTriangle, const Color &col)
{
	if(pSurface == NULL || pTriangle == NULL)
		return;

	ClippingRect clip = {0.0f, 0.0f, pSurface->width-1, pSurface->height-1};
	calculateRasterPixels(pSurface, pTriangle, clip);

	//determine rasterizing region
	//calculateTriangleRect(clip, pTriangle);
	//if(clip.top < 0) clip.top = 0;
	//if(clip.bottom >= pSurface->height) clip.bottom = pSurface->height-1;
	//for(int row = (int)clip.top; row <= (int)clip.bottom; row++)
		//calculateRasterPixels(row, clip.left, clip.right, pSurface, pTriangle);

	//rasterize the polygon
	if(pSurface->format == SFMT_P8)
	{
		while(!m_rasterLines.empty())
		{
			int start = 0, finish = 0;

			start = (m_rasterLines.front().least.pos.x < 0 ? 0 : m_rasterLines.front().least.pos.x);
			finish = (m_rasterLines.front().greatest.pos.x >= pSurface->width ? pSurface->width-1 : m_rasterLines.front().greatest.pos.x);

			for(int i = start; i <= finish; i++)
			{
				pSurface->pPaletteData[(int)m_rasterLines.front().least.pos.y * pSurface->width + i] = (SurfaceData8)col;
				m_rasterLines.pop();
			}
		}
	}
	else if(pSurface->format == SFMT_A8R8G8B8)
	{
		while(!m_rasterLines.empty())
		{
			int start = 0, finish = 0;

			start = (m_rasterLines.front().least.pos.x < 0 ? 0 : m_rasterLines.front().least.pos.x);
			finish = (m_rasterLines.front().greatest.pos.x >= pSurface->width ? pSurface->width-1 : m_rasterLines.front().greatest.pos.x);

			for(int i = start; i <= finish; i++)
			{
				pSurface->pColorData[(int)m_rasterLines.front().least.pos.y * pSurface->width + i] = (SurfaceData32)col;
			}
			m_rasterLines.pop();
		}
	}
}

void TriRasterizer::drawColor(Surface *pSurface, const Triangle *pTriangle)
{
	if(pSurface == NULL || pTriangle == NULL)
		return;

	//determine rasterizing region
	ClippingRect clip = {0.0f, 0.0f, pSurface->width-1, pSurface->height-1};
	calculateRasterPixels(pSurface, pTriangle, clip);

	//calculateTriangleRect(clip, pTriangle);
	//if(clip.top < 0) clip.top = 0;
	//if(clip.bottom >= pSurface->height) clip.bottom = pSurface->height-1;

	//for(int row = (int)clip.top; row <= (int)clip.bottom; row++)
	//	calculateRasterPixels(row, clip.left, clip.right, pSurface, pTriangle);

	//rasterize the polygon
	while(!m_rasterLines.empty())
	{
		rasterColor(pSurface, m_rasterLines.front(), pTriangle);
		m_rasterLines.pop();
	}
}

void TriRasterizer::drawTexture(Surface *pSurface, const Triangle *pTriangle, const Surface* pTexture)
{
	if(pSurface == NULL || pTriangle == NULL)
		return;

	//determine rasterizing region
	ClippingRect clip = {0.0f, 0.0f, pSurface->width-1, pSurface->height-1};
	calculateRasterPixels(pSurface, pTriangle, clip);

	//calculateTriangleRect(clip, pTriangle);
	//if(clip.top < 0) clip.top = 0;
	//if(clip.bottom >= pSurface->height) clip.bottom = pSurface->height-1;
	//for(int row = (int)clip.top; row <= (int)clip.bottom; row++)
	//	calculateRasterPixels(row, clip.left, clip.right, pSurface, pTriangle);

	//rasterize the polygon
	while(!m_rasterLines.empty())
	{
		rasterTexture(pSurface, m_rasterLines.front(), pTriangle, pTexture);
		m_rasterLines.pop();
	}
}

void TriRasterizer::drawTextureColor(Surface *pSurface, const Triangle *pTriangle, const Surface* pTexture)
{
	if(pSurface == NULL || pTriangle == NULL)
		return;

	//determine rasterizing region
	ClippingRect clip = {0.0f, 0.0f, pSurface->width-1, pSurface->height-1};
	calculateRasterPixels(pSurface, pTriangle, clip);

	//calculateTriangleRect(clip, pTriangle);
	//if(clip.top < 0) clip.top = 0;
	//if(clip.bottom >= pSurface->height) clip.bottom = pSurface->height-1;
	//for(int row = (int)clip.top; row <= (int)clip.bottom; row++)
	//	calculateRasterPixels(row, clip.left, clip.right, pSurface, pTriangle);

	//rasterize the polygon
	while(!m_rasterLines.empty())
	{
		rasterTextureColor(pSurface, m_rasterLines.front(), pTriangle, pTexture);
		m_rasterLines.pop();
	}
}




void QuadRasterizer::generateTriangles(const Quad *pQuad)
{
	Vertex center;
	FPInt a,r,g,b;
	for(int i = 0; i < 4; i++)
	{
		center.pos.x += pQuad->pnt[i].pos.x;
		center.pos.y += pQuad->pnt[i].pos.y;
		center.tex.u += pQuad->pnt[i].tex.u;
		center.tex.v += pQuad->pnt[i].tex.v;
		a += pQuad->pnt[i].col.a;
		r += pQuad->pnt[i].col.r;
		g += pQuad->pnt[i].col.g;
		b += pQuad->pnt[i].col.b;
	}
	center.pos.x /= 4;
	center.pos.y /= 4;
	center.tex.u /= 4;
	center.tex.v /= 4;
	a /= 4;
	r /= 4;
	g /= 4;
	b /= 4;
	center.col.a = a.whole;
	center.col.r = r.whole;
	center.col.g = g.whole;
	center.col.b = b.whole;

	for(int i = 0; i < 4; i++)
	{
		m_triangles[i].pnt[0] = pQuad->pnt[i];
		m_triangles[i].pnt[1] = pQuad->pnt[(i+1)%4];
		m_triangles[i].pnt[2] = center;
	}
}